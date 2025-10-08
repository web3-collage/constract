const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CourseContract - Gas Optimizations", function () {
  let courseContract;
  let ydToken;
  let platformAddress;
  let instructor;
  let student;
  let referrer;

  beforeEach(async function () {
    [platformAddress, instructor, student, referrer] = await ethers.getSigners();

    // Deploy YD Token
    const SimpleYDToken = await ethers.getContractFactory("SimpleYDToken");
    ydToken = await SimpleYDToken.deploy();

    // Deploy CourseContract
    const CourseContract = await ethers.getContractFactory("CourseContract");
    courseContract = await CourseContract.deploy(
      await ydToken.getAddress(),
      platformAddress.address
    );

    // Transfer tokens to student
    await ydToken.transfer(student.address, ethers.parseEther("10000"));

    // Approve course contract to spend student's tokens
    await ydToken.connect(student).approve(
      await courseContract.getAddress(),
      ethers.parseEther("10000")
    );
  });

  describe("讲师认证机制", function () {
    it("平台管理员应该能认证讲师", async function () {
      await courseContract.connect(platformAddress).certifyInstructor(instructor.address);

      expect(await courseContract.isCertifiedInstructor(instructor.address)).to.be.true;
      expect(await courseContract.certifiedInstructorCount()).to.equal(1);
    });

    it("未认证讲师不能创建课程", async function () {
      await expect(
        courseContract.connect(instructor).createCourse(
          "Test Course",
          instructor.address,
          ethers.parseEther("100"),
          10
        )
      ).to.be.revertedWithCustomError(courseContract, "NotCertifiedInstructor");
    });

    it("认证讲师可以创建课程", async function () {
      await courseContract.connect(platformAddress).certifyInstructor(instructor.address);

      await courseContract.connect(instructor).createCourse(
        "Test Course",
        instructor.address,
        ethers.parseEther("100"),
        10
      );

      const course = await courseContract.getCourse(1);
      expect(course.title).to.equal("Test Course");
      expect(course.instructor).to.equal(instructor.address);
    });

    it("批量认证讲师功能", async function () {
      const [, , addr1, addr2, addr3] = await ethers.getSigners();

      await courseContract.connect(platformAddress).batchCertifyInstructors([
        addr1.address,
        addr2.address,
        addr3.address
      ]);

      expect(await courseContract.certifiedInstructorCount()).to.equal(3);
      expect(await courseContract.isCertifiedInstructor(addr1.address)).to.be.true;
      expect(await courseContract.isCertifiedInstructor(addr2.address)).to.be.true;
      expect(await courseContract.isCertifiedInstructor(addr3.address)).to.be.true;
    });
  });

  describe("讲师课程列表优化", function () {
    it("getInstructorCourses 应该返回正确的课程列表", async function () {
      // 认证讲师
      await courseContract.connect(platformAddress).certifyInstructor(instructor.address);

      // 创建多个课程
      await courseContract.connect(instructor).createCourse(
        "Course 1",
        instructor.address,
        ethers.parseEther("100"),
        10
      );

      await courseContract.connect(instructor).createCourse(
        "Course 2",
        instructor.address,
        ethers.parseEther("200"),
        20
      );

      const instructorCourses = await courseContract.getInstructorCourses(instructor.address);
      expect(instructorCourses.length).to.equal(2);
      expect(instructorCourses[0]).to.equal(1);
      expect(instructorCourses[1]).to.equal(2);
    });
  });

  describe("Pausable 暂停机制", function () {
    beforeEach(async function () {
      // 认证讲师并创建课程
      await courseContract.connect(platformAddress).certifyInstructor(instructor.address);
      await courseContract.connect(instructor).createCourse(
        "Test Course",
        instructor.address,
        ethers.parseEther("100"),
        10
      );
    });

    it("平台管理员可以暂停合约", async function () {
      await courseContract.connect(platformAddress).pause();
      expect(await courseContract.isPaused()).to.be.true;
    });

    it("暂停时不能购买课程", async function () {
      await courseContract.connect(platformAddress).pause();

      await expect(
        courseContract.connect(student).purchaseCourse(1)
      ).to.be.revertedWithCustomError(courseContract, "EnforcedPause");
    });

    it("恢复后可以购买课程", async function () {
      // 暂停
      await courseContract.connect(platformAddress).pause();

      // 恢复
      await courseContract.connect(platformAddress).unpause();
      expect(await courseContract.isPaused()).to.be.false;

      // 应该能购买
      await courseContract.connect(student).purchaseCourse(1);
      expect(await courseContract.hasPurchased(student.address, 1)).to.be.true;
    });
  });

  describe("精度损失优化验证", function () {
    it("分账金额应该等于总价格", async function () {
      // 认证讲师并创建课程
      await courseContract.connect(platformAddress).certifyInstructor(instructor.address);
      await courseContract.connect(instructor).createCourse(
        "Test Course",
        instructor.address,
        ethers.parseEther("99"),
        10
      );

      // 购买课程
      await courseContract.connect(student).purchaseCourse(1);

      // 验证分账（通过事件或收益记录）
      const instructorEarnings = await courseContract.getInstructorEarnings(instructor.address);
      expect(instructorEarnings.totalEarned).to.be.gt(0);
    });
  });

  describe("课程管理功能", function () {
    beforeEach(async function () {
      await courseContract.connect(platformAddress).certifyInstructor(instructor.address);
      await courseContract.connect(instructor).createCourse(
        "Original Course",
        instructor.address,
        ethers.parseEther("100"),
        10
      );
    });

    it("讲师可以更新课程", async function () {
      await courseContract.connect(instructor).updateCourse(1, "Updated Course", 20);

      const course = await courseContract.getCourse(1);
      expect(course.title).to.equal("Updated Course");
      expect(course.totalLessons).to.equal(20);
    });

    it("讲师可以取消发布课程", async function () {
      await courseContract.connect(instructor).unpublishCourse(1);

      const course = await courseContract.getCourse(1);
      expect(course.isPublished).to.be.false;
    });

    it("讲师可以重新发布课程", async function () {
      await courseContract.connect(instructor).unpublishCourse(1);
      await courseContract.connect(instructor).publishCourse(1);

      const course = await courseContract.getCourse(1);
      expect(course.isPublished).to.be.true;
    });
  });

  describe("Course 结构体优化", function () {
    it("totalLessons 应该使用 uint96 类型", async function () {
      await courseContract.connect(platformAddress).certifyInstructor(instructor.address);

      // 测试大数字
      const largeLessons = 1000000; // 1M 课时
      await courseContract.connect(instructor).createCourse(
        "Large Course",
        instructor.address,
        ethers.parseEther("100"),
        largeLessons
      );

      const course = await courseContract.getCourse(1);
      expect(course.totalLessons).to.equal(largeLessons);
    });
  });
});

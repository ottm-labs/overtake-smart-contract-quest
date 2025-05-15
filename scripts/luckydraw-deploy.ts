import "@nomicfoundation/hardhat-chai-matchers";
import {Contract} from "ethers";
import {ethers, upgrades} from "hardhat";

async function main() {

    const LuckyDrawContract = await ethers.getContractFactory("LuckyDraw");
    const admins = ["0x7b8e257BCdCa0b50f0315A454b59e18B140A4962"];

    const luckydraw: Contract = await upgrades.deployProxy(LuckyDrawContract, {
        initializer: 'initialize',
    });
    console.log(luckydraw.address, "=============address=============")
}

// Call the main function and catch if there is any error
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

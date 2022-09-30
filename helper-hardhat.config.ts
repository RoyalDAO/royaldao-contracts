import { BigNumberish, ethers } from "ethers";

export interface networkConfigItem {
  blockConfirmations?: number;
  VRFCoordinatorV2: string;
  // entranceFee: BigNumberish;
  gasLane: string;
  callBackGasLimit: string;
  interval: string;
  subscriptionId?: string;
  deploy_parameters?: DeployParameters;
}

interface DeployParameters {
  executorMinDelay: number;
  executorProposers: any[];
  executors: any[];
  quorumPercentage: number;
  votingPeriod: number;
  votingDelay: number;
  vetoUntil: number;
}

export interface networkConfigInfo {
  [key: number]: networkConfigItem;
}

const networkConfig: networkConfigInfo = {
  5: {
    blockConfirmations: 6,
    // entranceFee: ethers.utils.parseEther("0.01"),
    VRFCoordinatorV2: "",
    gasLane: "",
    callBackGasLimit: "500000",
    interval: "120",
    subscriptionId: "505",
    deploy_parameters: {
      executorMinDelay: 272, //1 hour
      executorProposers: [],
      executors: [],
      quorumPercentage: 25, //25%
      votingPeriod: 272, //1 hour
      votingDelay: 272, //1 hour
      vetoUntil: 50,
    },
  },
  1337: {
    blockConfirmations: 1,
    // entranceFee: ethers.utils.parseEther("0.01"),
    VRFCoordinatorV2: "",
    gasLane: "",
    callBackGasLimit: "500000",
    interval: "30",
  },
};

const developmentChains = ["hardhat", "localhost"];

export { networkConfig, developmentChains };

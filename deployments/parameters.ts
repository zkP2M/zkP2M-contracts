import "module-alias/register";
import { BigNumber } from "ethers";
import { ONE_DAY_IN_SECONDS, THREE_MINUTES_IN_SECONDS, ZERO } from "@utils/constants";
import { ether, usdc } from "@utils/common/units";

// Deployment Parameters
export const SERVER_KEY_HASH = {
    "venmo": "0x2cf6a95f35c0d2b6160f07626e9737449a53d173d65d1683263892555b448d8f",
    "hdfc": [
        "0x06b0ad846d386f60e777f1d11b82922c6bb694216eed9c23535796ac404a7dfa", // acls01
        "0x1c1b5a203a9f1f15f6172969b9359e6a7572001de09471efd1586a67f7956fd8" // acls03
    ]
};


export const MIN_DEPOSIT_AMOUNT: any = {
    "upi": {
        "localhost": usdc(1),
        "goerli": usdc(1),
        "base": usdc(20),
        "base_staging": usdc(20),
        "mantle": usdc(1),
        "scroll": usdc(1)
    },
};
export const MAX_ONRAMP_AMOUNT: any = {
    "upi": {
        "localhost": usdc(998),
        "goerli": usdc(999),
        "base": usdc(25),
        "base_staging": usdc(25),
        "mantle": usdc(998),
        "scroll": usdc(998)
    },
};
export const INTENT_EXPIRATION_PERIOD: any = {
    "upi": {
        "localhost": ONE_DAY_IN_SECONDS.sub(1),
        "goerli": BigNumber.from(300),
        "base": ONE_DAY_IN_SECONDS,
        "base_staging": BigNumber.from(300),
        "mantle": BigNumber.from(300),
        "scroll": BigNumber.from(300)
    },
};
export const ONRAMP_COOL_DOWN_PERIOD: any = {
    "upi": {
        "localhost": ZERO,
        "goerli": ZERO,
        "base": ONE_DAY_IN_SECONDS,
        "base_staging": BigNumber.from(180),
        "mantle": ZERO,
        "scroll": ZERO
    },
};
export const SUSTAINABILITY_FEE: any = {
    "upi": {
        "localhost": ether(.002),
        "goerli": ether(.001),
        "base": ZERO,
        "base_staging": ZERO,
        "mantle": ZERO,
        "scroll": ZERO
    },
};
export const SUSTAINABILITY_FEE_RECIPIENT: any = {
    "upi": {
        "localhost": "",
        "goerli": "",
        "base": "0x0bC26FF515411396DD588Abd6Ef6846E04470227",
        "base_staging": "0xdd93E0f5fC32c86A568d87Cb4f08598f55E980F3",
        "mantle": "",
        "scroll": ""
    },
};

// Global Parameters
export const MULTI_SIG: any = {
    "localhost": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
    "goerli": "",
    "base": "0x0bC26FF515411396DD588Abd6Ef6846E04470227",
    "base_staging": "0xdd93E0f5fC32c86A568d87Cb4f08598f55E980F3",
    "mantle": "",
    "scroll": ""
};

// USDC
export const USDC: any = {
    "base": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "base_staging": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
};

// For Goerli and localhost
export const USDC_MINT_AMOUNT = usdc(1000000);
// export const USDC_RECIPIENT = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

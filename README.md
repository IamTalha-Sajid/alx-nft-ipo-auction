# MatchMaking Contract Deployment Guide

This guide covers the complete deployment process for the MatchMaking contract on BSC testnet and mainnet.

## 📋 Prerequisites

### 1. Install Dependencies
```bash
npm install
```

### 2. Compile Contracts
```bash
npx hardhat compile
```

### 3. Environment Setup
Create a `.env` file in the root directory with the following variables:

```bash
# Deployment Configuration
PRIVATE_KEY=your_private_key_here

# Network RPC URLs
BSC_TESTNET_RPC=your_bsc_testnet_rpc_url
BSC_RPC=your_bsc_mainnet_rpc_url

# Network Chain IDs
BSC_TESTNET_CHAIN_ID=97
BSC_CHAIN_ID=56

# Contract Configuration
HATCH_TOKEN_ADDRESS=your_hatch_token_address
TREASURY_ADDRESS=your_treasury_address
BACKEND_SIGNER_ADDRESS=your_backend_signer_address

# Phase Durations (in seconds)
MATCHMAKING_DURATION=1800
INTERMISSION_DURATION=300
MATCH_PLAYING_DURATION=3600

# Match Configuration
MATCH_FEE=5
LEVEL_TOLERANCE=2
SIGNATURE_EXPIRY_DURATION=300
MATCH_TIERS=[100,500,1000,5000]

# Verification
BSCSCAN_API_KEY=your_bscscan_api_key
```

## 🚀 Deployment Process

### Step 1: Deploy Contract

#### BSC Testnet Deployment
```bash
# Deploy MatchMaking contract
npx hardhat deploy --tags MatchMaking --network bscTestnet

# Setup contract configuration
npx hardhat deploy --tags MatchMakingSetup --network bscTestnet
```

#### BSC Mainnet Deployment
```bash
# Deploy MatchMaking contract
npx hardhat deploy --tags MatchMaking --network bsc

# Setup contract configuration
npx hardhat deploy --tags MatchMakingSetup --network bsc
```

### Step 2: Verify Contract

#### BSC Testnet Verification
```bash
# Verify proxy contract
npx hardhat verify --network bscTestnet <PROXY_ADDRESS>

# Verify implementation contract
npx hardhat verify --network bscTestnet <IMPLEMENTATION_ADDRESS>
```

#### BSC Mainnet Verification
```bash
# Verify proxy contract
npx hardhat verify --network bsc <PROXY_ADDRESS>

# Verify implementation contract
npx hardhat verify --network bsc <IMPLEMENTATION_ADDRESS>
```

### Step 3: Export Contract Data

#### BSC Testnet Export
```bash
npx hardhat export --export ./exports/bscTestnet.json --network bscTestnet
```

#### BSC Mainnet Export
```bash
npx hardhat export --export ./exports/bsc.json --network bsc
```

## 📊 Expected Output

### Deployment Output
```
Deploying MatchMaking with parameters:
- Deployer: 0x...
- Hatch Token: 0x...
- Treasury: 0x...
- Backend Signer: 0x...
- Matchmaking Duration: 30 minutes
- Intermission Duration: 5 minutes
- Match Playing Duration: 1 hours
MatchMaking deployed to: 0x...
Total Phase Interval: 1.5833333333333333 hours
```

### Setup Output
```
Setting up MatchMaking contract with parameters:
- Contract Address: 0x...
- Deployer: 0x...
- Match Fee: 5 %
- Level Tolerance: 2
- Signature Expiry Duration: 300 seconds
- Match Tiers: [100, 500, 1000, 5000]
- Setting Match Fee...
  ✓ Match fee set successfully
- Setting Level Tolerance...
  ✓ Level tolerance set successfully
- Setting Signature Expiry Duration...
  ✓ Signature expiry duration set successfully
- Setting Match Tiers...
  ✓ Match tiers set successfully

✓ MatchMaking setup completed successfully!
Contract is ready for use.
```

## 🔧 Contract Upgrade Process

### Update Implementation
```bash
# BSC Testnet
npx hardhat run scripts/update_implementation.ts --network bscTestnet

# BSC Mainnet
npx hardhat run scripts/update_implementation.ts --network bsc
```

### Verify Updated Contract
```bash
# Get new implementation address from upgrade output
npx hardhat verify --network bscTestnet <NEW_IMPLEMENTATION_ADDRESS>
```

## 📁 File Structure

After deployment, you'll have:

```
contract/hatch-matchmaking/
├── deployments/
│   ├── bscTestnet/
│   │   └── MatchMaking.json
│   └── bsc/
│       └── MatchMaking.json
├── exports/
│   ├── bscTestnet.json
│   └── bsc.json
└── artifacts/
    └── contracts/
        └── MatchMaking.sol/
            └── MatchMaking.json
```

## 🔍 Verification Commands

### Manual Verification (if auto-verification fails)

#### Proxy Contract
```bash
npx hardhat verify --network bscTestnet <PROXY_ADDRESS> \
  --constructor-args <DEFAULT_ADMIN> <HATCH_TOKEN> <TREASURY> <BACKEND_SIGNER> <MATCHMAKING_DURATION> <INTERMISSION_DURATION> <MATCH_PLAYING_DURATION>
```

#### Implementation Contract
```bash
npx hardhat verify --network bscTestnet <IMPLEMENTATION_ADDRESS>
```

## 🛡️ Security Checklist

- [ ] Private key is secure and not committed to version control
- [ ] All environment variables are properly set
- [ ] Contract addresses are verified on BSCScan
- [ ] Contract configuration is tested on testnet first
- [ ] Treasury and backend signer addresses are correct
- [ ] Match tiers and fees are appropriate for production

## 🚨 Troubleshooting

### Common Issues

1. **Insufficient BNB for deployment**
   - Ensure wallet has enough BNB for gas fees
   - Testnet: Get BNB from BSC testnet faucet

2. **Verification fails**
   - Check BSCScan API key is valid
   - Ensure constructor arguments match deployment
   - Try manual verification with explicit arguments

3. **Setup fails**
   - Verify all environment variables are set
   - Check that deployment completed successfully
   - Ensure deployer has admin role

4. **Export fails**
   - Ensure deployment files exist
   - Check network configuration in hardhat.config.ts
   - Verify contract artifacts are compiled

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Verify all environment variables are set correctly
3. Ensure you have sufficient BNB for gas fees
4. Test on testnet before mainnet deployment

## 🔄 Complete Workflow Example

```bash
# 1. Setup
npm install
npx hardhat compile

# 2. Deploy to testnet
npx hardhat deploy --tags MatchMaking --network bscTestnet
npx hardhat deploy --tags MatchMakingSetup --network bscTestnet

# 3. Verify on testnet
npx hardhat verify --network bscTestnet <PROXY_ADDRESS>

# 4. Export testnet data
npx hardhat export --export ./exports/bscTestnet.json --network bscTestnet

# 5. Deploy to mainnet (after testing)
npx hardhat deploy --tags MatchMaking --network bsc
npx hardhat deploy --tags MatchMakingSetup --network bsc

# 6. Verify on mainnet
npx hardhat verify --network bsc <PROXY_ADDRESS>

# 7. Export mainnet data
npx hardhat export --export ./exports/bsc.json --network bsc
```

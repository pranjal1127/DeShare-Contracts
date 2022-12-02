// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IncentiveToken.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

contract IncentiveManager is Ownable{
    using SafeMath for uint256; 

    uint public currentMonth;
    address public poolManager;
    address public admin;

    /// @dev 30.4368 days to take account for leap years.
    uint48 public constant SECONDS_IN_MONTH = 2629744;

    /// @notice Timestamp of the block in which last NRT transaction was sealed.
    uint256 public lastReleaseTimestamp;

    uint256 public rewardPool = 10000 ether;
    uint256 public incentivefactor;

    IncentiveToken incentiveToken;

    struct CreatorData {
        uint256 incentiveScore;
    }

    bytes32 constant TYPE_HASH_CREATOR = keccak256("CreatorData(uint256 incentiveScore)"); 


    mapping (uint => mapping(address => uint)) earnedRewards; 

    constructor(address _poolAddress,address _token, address _admin){
        currentMonth = 0;
        lastReleaseTimestamp = block.timestamp;
        incentiveToken = IncentiveToken(_token);
        poolManager = _poolAddress;
        admin = _admin;
    }

    function releaseRewardPool(uint _incentivefactor) onlyOwner external{
        // Burn your existing money 
        require(
                block.timestamp - lastReleaseTimestamp >= SECONDS_IN_MONTH,
                "MONTH_NOT_FINISHED"
            );
        // Make Reward Pool 
        incentiveToken.mintReward(rewardPool.mul(90).div(100));
        // Give some amount to pool;
        incentiveToken.transfer(poolManager,rewardPool.mul(10).div(100));

        incentivefactor = _incentivefactor;
        lastReleaseTimestamp = block.timestamp;
        currentMonth++;
    }

    function claimIncentiveWithSig(uint256 _incentiveScore,bytes calldata _signature) public{
        //TODO : let's read all data from lens smart contracts and build fromula instead of getting form backend 
        address signer = verifySignature(Strings.toString(_incentiveScore),_signature);
        require(signer == admin, "Invalid Signature");
        incentiveToken.transfer(msg.sender,_incentiveScore);
    }   



     // ------------------------------------------ for Signature Verification ----------------------------------------------------------
     // TODO: Sign with EIP712
    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            uint8,
            bytes32,
            bytes32
        )
    {
        require(sig.length == 65);
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }

    // Returns the address that signed a given string message
    function verifySignature(string memory message, bytes memory signature)
        public
        pure
        returns (address signer)
    {
        // The message header we will fill in the length next
        string memory header = "\x19Ethereum Signed Message:\n000000";
        uint256 lengthOffset;
        uint256 length;
        assembly {
            // The first word of a string is its length
            length := mload(message)
            // The beginning of the base-10 message length in the prefix
            lengthOffset := add(header, 57)
        }
        // Maximum length we support
        require(length <= 999999);
        // The length of the message's length in base-10
        uint256 lengthLength = 0;
        // The divisor to get the next left-most message length digit
        uint256 divisor = 100000;
        // Move one digit of the message length to the right at a time
        while (divisor != 0) {
            // The place value at the divisor
            uint256 digit = length / divisor;
            if (digit == 0) {
                // Skip leading zeros
                if (lengthLength == 0) {
                    divisor /= 10;
                    continue;
                }
            }
            // Found a non-zero digit or non-leading zero digit
            lengthLength++;
            // Remove this digit from the message length's current value
            length -= digit * divisor;
            // Shift our base-10 divisor over
            divisor /= 10;

            // Convert the digit to its ASCII representation (man ascii)
            digit += 0x30;
            // Move to the next character and write the digit
            lengthOffset++;
            assembly {
                mstore8(lengthOffset, digit)
            }
        }
        // The null string requires exactly 1 zero (unskip 1 leading 0)
        if (lengthLength == 0) {
            lengthLength = 1 + 0x19 + 1;
        } else {
            lengthLength += 1 + 0x19;
        }
        // Truncate the tailing zeros from the header
        assembly {
            mstore(header, lengthLength)
        }

        uint8 v;
        bytes32 r;
        bytes32 s;

        (v, r, s) = splitSignature(signature);
        // Perform the elliptic curve recover operation
        bytes32 check = keccak256(abi.encodePacked(header, message));
        return ecrecover(check, v, r, s);

    }

}

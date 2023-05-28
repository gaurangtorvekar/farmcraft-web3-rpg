// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract FarmCraft is ERC721, Ownable {
    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;

    uint256 public nextTokenId;
    uint256 public totalCrops;
    uint256 public totalFarmers;
    uint256 public totalSeeds;
    uint256 public totalCropsSold;
    uint256 public totalGoldEarned;

    uint256 public constant QUEST_DURATION = 1 minutes;
    uint256 public constant SEEDS_FOR_GOLD = 5; // Number of crops required to buy 1 GOLD
    uint256 public constant CROPS_FOR_GOLD = 10; // Number of crops required to buy 1 GOLD

    struct Crop {
        uint256 maturityTime;
        uint256 yield;
        uint256 rewards;
        uint256 plantedAt;
        bool harvested;
    }

    struct Farmer {
        address owner;
        uint256 experience;
        uint256 level;
        uint256[] crops;
        uint256 seeds;
        uint256 gold;
        uint256 cropsEarned;
        uint256 questEndTime;
        bool questActive;
        string imageIpfsHash;
    }

    struct CropType {
        uint256 maturityTime;
        uint256 yield;
        uint256 rewards;
        uint256 seedCost;
    }

    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => Crop) private crops;
    mapping(uint256 => Farmer) private farmers;
    mapping(uint256 => CropType) private cropTypes;
    mapping(uint256 => EnumerableSet.UintSet) private farmerCrops;

    Counters.Counter private cropTypeCounter;

    constructor() ERC721("FarmCraft Farmer", "FARMER") {
        nextTokenId = 1;
    }

    // Getter functions for the mappings
    function getCrop(uint256 cropId) external view returns (Crop memory) {
        return crops[cropId];
    }

    function getFarmer(uint256 farmerId) external view returns (Farmer memory) {
        return farmers[farmerId];
    }

    function getCropType(uint256 cropTypeId) external view returns (CropType memory) {
        return cropTypes[cropTypeId];
    }

    function _initiateMetadata(uint256 farmerId) private {
        Farmer storage farmer = farmers[farmerId];
        _setTokenURI(farmerId, _constructTokenURI(farmerId, farmer));
    }

    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = tokenURI;
    }

    function _constructTokenURI(uint256 tokenId, Farmer memory farmer) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"name":"Farmer #',
                uintToStr(tokenId),
                '","description":"FarmCraft Farmer","image":"',
                farmer.imageIpfsHash,
                '","attributes":[{"trait_type":"Experience","value":',
                uintToStr(farmer.experience),
                '},{"trait_type":"Level","value":',
                uintToStr(farmer.level),
                '},{"trait_type":"Seeds","value":',
                uintToStr(farmer.seeds),
                '},{"trait_type":"Gold","value":',
                uintToStr(farmer.gold),
                '},{"trait_type":"Crops","value":',
                uintToStr(farmer.cropsEarned),
                '}]}' 
            )
        );
    }

    function mintFarmer(string memory imageIpfsHash) external {
        _safeMint(msg.sender, nextTokenId);
        farmers[nextTokenId] = Farmer(
            msg.sender,
            0,
            1,
            new uint256[](0),
            0,
            0,
            0,
            0,
            false,
            imageIpfsHash
        );
        _initiateMetadata(nextTokenId);
        nextTokenId++;
        totalFarmers++;
    }

    function buySeeds(uint256 farmerId, uint256 amount) external {
        require(ownerOf(farmerId) == msg.sender, "Only farmer owner can buy seeds");

        Farmer storage farmer = farmers[farmerId];
        uint256 seedsToBuy = amount * SEEDS_FOR_GOLD; // Buy 5 seeds per 1 GOLD

        require(farmer.gold >= amount, "Insufficient GOLD");

        farmer.gold -= amount;
        farmer.seeds += seedsToBuy;
        totalSeeds += seedsToBuy;
        _initiateMetadata(farmerId);
    }

    function startForagingQuest(uint256 farmerId) external {
        require(ownerOf(farmerId) == msg.sender, "Only farmer owner can start the quest");
        require(!farmers[farmerId].questActive, "Quest is already active");

        farmers[farmerId].questActive = true;
        farmers[farmerId].questEndTime = block.timestamp + QUEST_DURATION;
        _initiateMetadata(farmerId);
    }

    function endForagingQuest(uint256 farmerId) external {
        require(ownerOf(farmerId) == msg.sender, "Only farmer owner can end the quest");
        require(farmers[farmerId].questActive, "Quest is not active");
        require(block.timestamp >= farmers[farmerId].questEndTime, "Quest is not yet completed");

        farmers[farmerId].seeds += 1; // Reward 1 SEED for completing the quest
        farmers[farmerId].questActive = false;
        farmers[farmerId].questEndTime = 0;
        totalSeeds++;
        farmers[farmerId].experience += 1; // Increase experience for completing a quest
        _initiateMetadata(farmerId);
    }

    function plantCrop(uint256 farmerId, uint256 cropTypeId) external {
        require(ownerOf(farmerId) == msg.sender, "Only farmer owner can plant crops");
        require(cropTypeId < cropTypeCounter.current(), "Invalid crop type ID");

        Farmer storage farmer = farmers[farmerId];
        CropType storage cropType = cropTypes[cropTypeId];
        require(farmer.seeds >= cropType.seedCost, "Insufficient SEEDs");

        uint256 cropId = totalCrops;
        crops[cropId] = Crop(cropType.maturityTime, cropType.yield, cropType.rewards, block.timestamp, false);
        farmerCrops[farmerId].add(cropId);
        farmer.seeds -= cropType.seedCost;
        totalCrops++;
        farmer.experience += 1; // Increase experience for planting a crop
        _initiateMetadata(farmerId);
    }

    function harvestCrop(uint256 farmerId, uint256 cropId) external {
        require(ownerOf(farmerId) == msg.sender, "Only farmer owner can harvest crops");
        require(cropId < totalCrops, "Invalid crop ID");
        require(!crops[cropId].harvested, "Crop has already been harvested");

        Farmer storage farmer = farmers[farmerId];
        Crop storage crop = crops[cropId];

        require(block.timestamp >= crop.plantedAt + crop.maturityTime, "Crop is not yet mature");

        crop.harvested = true;
        farmer.cropsEarned += crop.yield;
        farmer.gold += crop.rewards;
        totalCropsSold += crop.yield;
        totalGoldEarned += crop.rewards;
        farmer.experience += 1; // Increase experience for harvesting a crop
        _initiateMetadata(farmerId);
    }

    function sellCrops(uint256 farmerId, uint256 amount) external {
        require(ownerOf(farmerId) == msg.sender, "Only farmer owner can sell crops");
        require(farmers[farmerId].cropsEarned >= amount, "Insufficient crops to sell");

        Farmer storage farmer = farmers[farmerId];
        uint256 goldToEarn = amount / CROPS_FOR_GOLD; // Sell 10 cropsEarned for 1 GOLD

        farmer.cropsEarned -= amount;
        farmer.gold += goldToEarn;
        totalCropsSold += amount;
        totalGoldEarned += goldToEarn;
        farmer.experience += 1; // Increase experience for selling crops
        _initiateMetadata(farmerId);
    }

    function addCropType(uint256 maturityTime, uint256 yield, uint256 rewards, uint256 seedCost) external onlyOwner {
        CropType storage newCropType = cropTypes[cropTypeCounter.current()];
        newCropType.maturityTime = maturityTime;
        newCropType.yield = yield;
        newCropType.rewards = rewards;
        newCropType.seedCost = seedCost;
        cropTypeCounter.increment();
    }

    function uintToStr(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory _tokenURI = _tokenURIs[tokenId];
        string memory baseURI = _baseURI();
        if (bytes(baseURI).length == 0) {
            return _tokenURI;
        }
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(baseURI, _tokenURI));
        }
        return super.tokenURI(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://gateway.pinata.cloud/ipfs/QmQGgmAv2LybwF3N7EQPHiq3bevku3LEZvHMM1aUH7C1Zh/";
    }
}

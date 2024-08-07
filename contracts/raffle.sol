// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// Custom errors for better gas efficiency
error Raffle_sendMoreToEnterRaffle();
error Raffle_RaffleNotOpen();
error Raffle__TransferFailed();

contract Raffle is RrpRequesterV0 {
    // Enum to represent the state of the raffle
    enum RaffleState {
        OPEN,
        CLOSED
    }
    // Events to emit for various actions
    event RequestedRaffleWinner(uint256 indexed requestId);
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);
    event RequestedUint256(bytes32 indexed requestId);
    event ReceivedUint256(bytes32 indexed requestId, uint256 response);
    event TimeElapsed(bool timeElapsed);

    // State variables
    address public manager; // Address of the raffle manager
    address public recipient; // Address to receive the entry fees
    address [] public players; // List of players in the raffle
    address payable public winner; // Address of the winner
    uint256 public interval; // Time interval for the raffle
    uint256 public lastTime; // Last timestamp when the raffle was opened
    uint256 public lastBlock; // Last block number when the raffle was opened
    uint256 public lastWinner; // Index of the last winner
    uint256 public entryFee; // Entry fee for the raffle
    RaffleState private s_raffleState; // Current state of the raffle

    // QRNG related variables
    address public airnode;
    bytes32 public endpointIdUint256;
    address public sponsorWallet;
    uint256 public _qrngUint256;
    mapping(bytes32 => bool) public expectingRequestWithIdToBeFulfilled;

    // NFT prize variables
    IERC721 public nftPrize;
    uint256 public nftTokenId;

    // Constructor to initialize the contract
    constructor(
        uint256 _interval,
        uint256 _entryFee,
        address _airnodeRrp
    ) RrpRequesterV0(_airnodeRrp) {
        manager = msg.sender;
        recipient = msg.sender;
        interval = _interval;
        entryFee = _entryFee;
        lastTime = block.timestamp;
        lastBlock = block.number;
        s_raffleState = RaffleState.OPEN;
    }

    // Modifier to restrict access to only the manager
    modifier onlyOwner() {
        require(
            msg.sender == manager,
            "Only the manager can call this function"
        );
        _;
    }

    // Function to set QRNG request parameters
    function setRequestParameters(
        address _airnode,
        bytes32 _endpointIdUint256,
        address _sponsorWallet
    ) external onlyOwner {
        airnode = _airnode;
        endpointIdUint256 = _endpointIdUint256;
        sponsorWallet = _sponsorWallet;
    }

    // Function to set the NFT prize
    function setNftPrize(
        IERC721 _nftPrize,
        uint256 _nftTokenId
    ) external onlyOwner {
        nftPrize = _nftPrize;
        nftTokenId = _nftTokenId;
    }

    // Function to set the recipient address
    function setRecipient(address _recipient) external onlyOwner {
        recipient = _recipient;
    }

    // Function to enter the raffle
    function enterRaffle() external payable {
        if (msg.value < entryFee) {
            revert Raffle_sendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }
        players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
        // Start the interval timer when there are at least 4 players
        if (players.length >= 4) {
            lastTime = block.timestamp;
        }
    }

    // Function to enter the raffle multiple times
    function enterRaffleMultipleTimes(
        uint256 numberOfEntries
    ) external payable {
        uint256 totalEntryFee = entryFee * numberOfEntries;
        if (msg.value < totalEntryFee) {
            revert Raffle_sendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }
        for (uint256 i = 0; i < numberOfEntries; i++) {
            players.push(payable(msg.sender));
            emit RaffleEnter(msg.sender);
        }
        if (players.length >= 4) {
            lastTime = block.timestamp;
        }
    }

    // Function to check if the interval has elapsed and pick a winner if it has
    function checkUpkeep() external {
        if (
            block.timestamp - lastTime >= interval &&
            s_raffleState == RaffleState.OPEN
        ) {
            pickWinner();
            // Emit the time elapsed
            emit TimeElapsed(true);
        }
    }

    // Internal function to request a random number from QRNG
    function makeRequestUint256() internal {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode,
            endpointIdUint256,
            address(this),
            sponsorWallet,
            address(this),
            this.fulfillUint256.selector,
            ""
        );
        expectingRequestWithIdToBeFulfilled[requestId] = true;
        emit RequestedUint256(requestId);
    }

    // Callback function to handle the QRNG response
    function fulfillUint256(
        bytes32 requestId,
        bytes calldata data
    ) external onlyAirnodeRrp {
        require(
            expectingRequestWithIdToBeFulfilled[requestId],
            "Request ID not known"
        );
        expectingRequestWithIdToBeFulfilled[requestId] = false;
        uint256 qrngUint256 = abi.decode(data, (uint256));
        _qrngUint256 = qrngUint256;
        finalizePickWinner();
        emit ReceivedUint256(requestId, qrngUint256);
    }

    // Internal function to pick a winner
    function pickWinner() internal onlyOwner {
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle_RaffleNotOpen();
        }
        if (players.length == 0) {
            revert Raffle_RaffleNotOpen();
        }
        s_raffleState = RaffleState.CLOSED;
        makeRequestUint256();
    }

    // Internal function to finalize the winner selection and transfer the prize
    function finalizePickWinner() internal {
        if (players.length == 0) {
            revert("No players in the raffle");
        }
        // Use the random number to pick a winner
        uint256 indexOfWinner = _qrngUint256 % players.length;
        address payable recentWinner = payable(players[indexOfWinner]);
        winner = recentWinner;
        players = new address payable[](0);
        s_raffleState = RaffleState.OPEN;
        lastTime = block.timestamp;
        lastBlock = block.number;

        // Transfer the NFT prize to the winner
        nftPrize.safeTransferFrom(address(this), recentWinner, nftTokenId);

        emit WinnerPicked(recentWinner);
    }

    // Function to withdraw the fees to the manager's address
    function withdrawFees() external onlyOwner {
        (bool success, ) = recipient.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    // Function to change the manager
    function changeManager(address _manager) external onlyOwner {
        manager = _manager;
    }

    // Function to change the entry fee
    function changeEntryFee(uint256 _entryFee) external onlyOwner {
        entryFee = _entryFee;
    }

    // Function to change the interval
    function changeInterval(uint256 _interval) external onlyOwner {
        interval = _interval;
    }

    // Function to get the list of players
    function getPlayers() external view returns (address[] memory) {
        return players;
    }

    // Function to get the current state of the raffle
    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    // Function to get the winner
    function getWinner() external view returns (address) {
        return winner;
    }

    // Function to get the manager
    function getManager() external view returns (address) {
        return manager;
    }

    // Function to get the entry fee
    function getEntryFee() external view returns (uint256) {
        return entryFee;
    }

    // Function to get the interval
    function getInterval() external view returns (uint256) {
        return interval;
    }

    // Function to get the time elapsed since the raffle was opened
    function getTimeAfterOpen() external view returns (uint256) {
        return block.timestamp - lastTime;
    }
}
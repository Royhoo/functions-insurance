// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "hardhat/console.sol";
import "./dev/functions/FunctionsClient.sol";

contract ParametricInsurance is FunctionsClient {
    using Functions for Functions.Request;

    bytes32 public latestRequestId;
    bytes public latestResponse;
    bytes public latestError;
    event OCRResponse(bytes32 indexed requestId, bytes result, bytes err);

    // Number of days with temperature below threshold
    uint256 public constant COLD_DAYS_THRESHOLD = 2;

    // Number of insurance days to check temperature
    uint256 public constant INSURANCE_DAYS = 3;

    // The date begin check temperature
    uint256 public constant BEGIN_EXECUTE_REQUEST_DAY = 11;

    // Deadline you can purchase of insurance or capital injection. Must be earlier than BEGIN_EXECUTE_REQUEST_DAY
    uint256 public constant INSURE_DEADLINE = 10;

    // Number of seconds in a day. 600 for testing, 86400 for Production
    uint256 public constant DAY_IN_SECONDS = 600; 
    
    // Check if the contract active or end
    bool public contractActive;
    
    // Check if the contract should pay to client
    bool public shouldPayClient;
    
    // how many days with cold weather in a row
    uint256 public consecutiveColdDays = 0;

    // how many days checked
    uint256 public checkedDays = 0;

    // the temperature below threshold is considered as cold(in Fahrenheit)
    uint256 public coldTemp = 60;
    
    // current temperature for the location
    uint256 public currentTemperature;
    
    // when the last temperature check was performed
    uint256 public currentTempDateChecked;

    // deploy timestamp
    uint256 public deployTimestamp;

    // Mapping to keep track of insurers and their capital
    mapping(address => uint256) public insurers;

    // Mapping to keep track of policyholders and their premium
    mapping(address => uint256) public policyholders;

    uint256 public totalInsurerCapital;

    uint256 public totalPolicyholdersPremium;

    // Insurance payout ratio, must meet: totalInsurerCapital >= (odds - 1) * totalPolicyholdersPremium
    uint256 public odds = 2;

    constructor(address oracle) FunctionsClient(oracle) payable {
        shouldPayClient = false;
        deployTimestamp = block.timestamp;
        currentTempDateChecked = block.timestamp;
        contractActive = true;
        currentTemperature = 0;
    }

    /**
     * @dev Prevents a data request to be called unless it's been a day since the last call (to avoid spamming and spoofing results)
     */
    modifier callFrequencyOncePerDay() {
        require((block.timestamp- currentTempDateChecked) > DAY_IN_SECONDS,
                'Can only check temperature once per day');
        _;
    }

    /**
     * @dev Prevents a function being run unless contract is still active
     */
    modifier onContractActive() {
        require(contractActive == true ,
                'Contract has ended, cant interact with it anymore unless draw');
        _;
    }

    /**
     * @dev Prevents draw unless meet the condition
     */
    modifier beginDraw() {
        require(contractActive == false, 'Cant draw now, please wait!');
        _;
    }

    /**
     * @dev Prevents a function being run unless the time has come
     */
    modifier beginExecuteRequest() {
        require((block.timestamp - deployTimestamp) > DAY_IN_SECONDS * BEGIN_EXECUTE_REQUEST_DAY
                ,'Cant execute request now, please wait!');
        _;
    }

    /**
     * @dev Can only purchase of insurance or capital injection before deadline
     */
    modifier beforeInsureDeadline() {
        require((block.timestamp - deployTimestamp) < DAY_IN_SECONDS * INSURE_DEADLINE
                ,'Deadline arrives, cant purchase or injection!');
        _;
    }

    /**
     * @notice Insurer injection capital
     */
    function capitalInjection() beforeInsureDeadline() public payable {
        insurers[msg.sender] = insurers[msg.sender] + msg.value;
        totalInsurerCapital += msg.value;

        console.log("capitalInjection msg.sender=%s insurers[msg.sender]=%d", msg.sender, insurers[msg.sender]);
    }

    /**
     * @notice Purchase of insurance
     */
    function purchaseInsurance() beforeInsureDeadline() public payable {
        require(totalInsurerCapital >= (odds - 1) * (totalPolicyholdersPremium + msg.value),
                "The compensation fund is insufficient");
    
        policyholders[msg.sender] = policyholders[msg.sender] + msg.value;
        totalPolicyholdersPremium += msg.value;

        console.log("purchaseInsurance msg.sender=%s policyholders[msg.sender]=%d", msg.sender, policyholders[msg.sender]);
    }

    /**
     * @notice Send a simple request
     * @param source JavaScript source code
     * @param secrets Encrypted secrets payload
     * @param args List of arguments accessible from within the source code
     * @param subscriptionId Billing ID
     */
    function executeRequest(
        string calldata source,
        bytes calldata secrets,
        Functions.Location secretsLocation,
        string[] calldata args,
        uint64 subscriptionId,
        uint32 gasLimit
    ) public callFrequencyOncePerDay() onContractActive() beginExecuteRequest() returns (bytes32) {
        Functions.Request memory req;
        req.initializeRequest(Functions.Location.Inline, Functions.CodeLanguage.JavaScript, source);
        if (secrets.length > 0) {
        if (secretsLocation == Functions.Location.Inline) {
            req.addInlineSecrets(secrets);
        } else {
            req.addRemoteSecrets(secrets);
        }
        }
        if (args.length > 0) req.addArgs(args);

        bytes32 assignedReqID = sendRequest(req, subscriptionId, gasLimit);
        latestRequestId = assignedReqID;
        return assignedReqID;
    }

    /**
     * @notice Callback that is invoked once the DON has resolved the request or hit an error
     *
     * @param requestId The request ID, returned by sendRequest()
     * @param response Aggregated response from the user code
     * @param err Aggregated error from the user code or from the execution pipeline
     * Either response or error parameter will be set, but never both
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
      latestResponse = response;
      latestError = err;
      emit OCRResponse(requestId, response, err);
      // once callback happens, mark the timestamp
      currentTempDateChecked = block.timestamp;
      currentTemperature = uint256(bytes32(response));

      // if current temperature is under temperature which considered as cold, number of cold days inrement
      if (currentTemperature > coldTemp) {
          consecutiveColdDays = 0;
      } else {
          consecutiveColdDays += 1;
      }
      checkedDays++;

      if(consecutiveColdDays >= COLD_DAYS_THRESHOLD || checkedDays >= INSURANCE_DAYS) {
          if(consecutiveColdDays >= COLD_DAYS_THRESHOLD) {
            shouldPayClient = true;
          }

          contractActive = false;
      }
    }

    /**
     * @notice draw capital,if there is money left
     */
    function capitalDraw() beginDraw() public {
        require(insurers[msg.sender] > 0, "There is nothing to draw!");
        uint256 residue = 0;
        if(shouldPayClient) {
            residue = totalInsurerCapital - totalPolicyholdersPremium * odds;
        } else{
            residue = totalInsurerCapital + totalPolicyholdersPremium;
        }

        require(residue > 0, "There is nothing to draw!");
        uint256 drawAmt = (insurers[msg.sender] * residue) / totalInsurerCapital;
        if(drawAmt > address(this).balance){
            drawAmt = address(this).balance;
        }
        (bool sent, /*bytes memory data*/) = payable(msg.sender).call{value: drawAmt}("");
        require(sent, "Failure! Please try again!");
        insurers[msg.sender] = 0;
        console.log("capitalDraw msg.sender=%s drawAmt=%d", msg.sender, drawAmt);
    }

    /**
     * @notice Clint draw if it's should pay 
     */
    function clintDraw() beginDraw() public {
        require(shouldPayClient && policyholders[msg.sender] > 0, "There is nothing to draw!");
        uint256 drawAmt = policyholders[msg.sender] * odds;
        (bool sent, /*bytes memory data*/) = payable(msg.sender).call{value: drawAmt}("");
        require(sent, "Failure! Please try again!");
        policyholders[msg.sender] = 0;
        console.log("clintDraw msg.sender=%s drawAmt=%d", msg.sender, drawAmt);
    }

    // local test
    /*function mockFulfill() public {
        shouldPayClient = true;
        contractActive = false;
    }*/

    /**
     * @dev Receive function so contract can receive ether when required
     */
    receive() external payable {}
}
pragma solidity ^0.7.0;

/**
* @title Bounties
* @author Allan Patterson - <joshua.cassidy@consensys.net>
* @dev Simple smart contract which allows any user to issue a bounty in ETH linked to requirements 
*      which anyone else can fulfill by submitting their evidence of fulfillment, which the issuer may either accept or cancel.
*   source https://kauri.io/communities/Getting%20started%20with%20dapp%20development/remix-ide-your-first-smart-contract/
*/
contract Bounties {

    /**
    * Enums
    */
    
    enum BountyStatus { CREATED, ACCEPTED, CANCELLED }

    /**
    * Structs
    */

    struct Fulfillment {
        bool accepted;
        address payable fulfiller; //payable for fulfillment
        string data;
    }

    struct Bounty {
        address payable issuer; //payable for cancellation
        uint deadline;
        string data;
        BountyStatus status;
        uint amount; //in wei
    }

    /**
     * Storage
     */
     
    Bounty[] public bounties;
    
    //Fulfillment[] public fulfillments;
    
    mapping (uint => Fulfillment[]) fulfillments;

    /**
    * @dev constructor
    */
    constructor() public {}

    /**
     * This function allows for the creation of a bounty, with a specified completion deadline.  The msg.sender "owns" the bounty thereafter.
     **/
    
    function issueBounty(
        string memory _data,
        uint64 _deadline
    ) public payable hasValue() validateDeadline(_deadline) returns (uint) {
        bounties.push(Bounty(msg.sender, _deadline, _data, BountyStatus.CREATED, msg.value));
        emit BountyIssued(bounties.length - 1, msg.sender, msg.value, _data);
        return (bounties.length - 1);
    }

    /**
     * This function should store a fulfilment record attached to the given bounty. The msg.sender should be recorded as the fulfiller.
    **/ 
    function fulfilBounty(
        uint _bountyId, 
        string memory _data
    ) public payable bountyExists(_bountyId) isBeforeDeadline(_bountyId) hasBountyStatus(_bountyId, BountyStatus.CREATED) isNotIssuer(_bountyId, msg.sender) returns (uint) {
        fulfillments[_bountyId].push(Fulfillment(false, msg.sender, _data));
        emit BountyFulfilled(_bountyId, fulfillments[_bountyId].length - 1, msg.sender, _data);
        return fulfillments[_bountyId].length - 1;
    }
    
    /**
     * This function should accept the given fulfilment if a record of it exists against the given bounty. It should then pay the bounty to the fulfiller.
     */
    function acceptFulfilment(
        uint _bountyId, 
        uint _fulfillmentId
    ) public payable bountyExists(_bountyId) isIssuer(_bountyId) hasBountyStatus(_bountyId, BountyStatus.CREATED) fulfillmentExists(_bountyId, _fulfillmentId) fulfillmentPending(_bountyId, _fulfillmentId) {
        //Set fulfillment to true, set bounty to fulfilled, disburse funds
        //Note: For acceptFulfilment you need to use the address.transfer(uint amount) function to send the ETH to the fulfiller.   
        fulfillments[_bountyId][_fulfillmentId].accepted = true;
        bounties[_bountyId].status = BountyStatus.ACCEPTED;
        fulfillments[_bountyId][_fulfillmentId].fulfiller.transfer(bounties[_bountyId].amount);
        emit AcceptFulfillment(_bountyId, bounties[_bountyId].issuer, _fulfillmentId, fulfillments[_bountyId][_fulfillmentId].fulfiller, bounties[_bountyId].amount);
        return;
    }

    /**
     * This function should cancel the bounty, if it has not already been accepted, and send the funds back to the issuer
     */

    function cancelBounty(
        uint _bountyId
    ) public payable bountyExists(_bountyId) isIssuer(_bountyId) hasBountyStatus(_bountyId, BountyStatus.CREATED) {
        //Set the bounty status to cancelled, and send the funds back to the issuer.
        bounties[_bountyId].status = BountyStatus.CANCELLED;
        bounties[_bountyId].issuer.transfer(bounties[_bountyId].amount);
        emit CancelBounty(_bountyId, bounties[_bountyId].issuer, bounties[_bountyId].amount);
        return;
    }

    /**
     * Modifiers
     */
     
    /**
     * modifiers for issuing
     */
     
    modifier validateDeadline(uint _newDeadline) {
        require(_newDeadline > block.timestamp);
        _;
    }
        
    modifier hasValue() {
        require(msg.value > 0);
        _;
    }
    
    /**
     * modifiers for fulfillment
     */
     
    modifier bountyExists(uint _bountyId) {
        require(_bountyId < bounties.length);
        _;
    }

    modifier isBeforeDeadline(uint _bountyId) {
        require(bounties[_bountyId].deadline > block.timestamp);
        _;
    }

    /*****
    modifier isStillPending(uint _bountyId) {
        require(bounties[_bountyId].status == BountyStatus.CREATED);
        _;
    }
    */
    
    /**
     * More generalized form in case we need to check something other than CREATED.
     */
    
    modifier hasBountyStatus(uint _bountyId, BountyStatus _bountyStatus) {
        require(bounties[_bountyId].status == _bountyStatus);
        _;
    }
    
    modifier isNotIssuer(uint _bountyId, address _fulfillmentSender) {
        require(bounties[_bountyId].issuer != _fulfillmentSender);
        _;
    }

    /**
     * modifiers for accept/cancel
     */

    modifier fulfillmentExists(uint _bountyId, uint _fulfillmentId) {
        require(_fulfillmentId < fulfillments[_bountyId].length);
        _;
    }
    
    /**
     * Ensures we can't accpet a fulfillment a second time
     */
     
    modifier fulfillmentPending(uint _bountyId, uint _fulfillmentId) {
        require (fulfillments[_bountyId][_fulfillmentId].accepted == false);
        _;
    }

    modifier isIssuer(uint _bountyId) {
        require(bounties[_bountyId].issuer == msg.sender);
        _;
    }
    
    /**
     * Events
     */
     
     event BountyIssued(uint bounty_id, address issuer, uint amount, string data);
     
     event BountyFulfilled(uint bounty_id, uint fulfillment_id, address fulfiller, string data);
     
     event AcceptFulfillment(uint bounty_id, address issuer, uint fulfillment_id, address fulfiller, uint amount);

     event CancelBounty(uint bounty_id, address issuer, uint amount);
}

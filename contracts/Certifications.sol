pragma solidity >=0.5.0 <0.6.0;

import "./installed_contracts/zeppelin/contracts/math/SafeMath.sol";
import "./installed_contracts/zeppelin/contracts/ownership/Ownable.sol";

/**
 * @title Certification Smart Contract 
 * @author Harsh Rajat | https://github.com/HarshRajat/
 * @notice Create Certification Smart Contract to administer, award and manage pupils certifications 
 * @dev This Contract handles management of pupils certications
 */
 
contract Certification is Ownable {
    // Using SafeMath Library 
    using SafeMath for uint;
    
    /* ***************
    * DEFINE ENUMS
    *************** */
    enum assignmentInfo { Inactive, Pending, Completed, Cancelled } // for assignment information
    
    /* ***************
    * DEFINE CONSTANTS
    *************** */
    
    /* ***************
    * DEFINE STRUCTURES
    *************** */
    /* Admin Struct handles the admin mapping of address as well as the id to which they are 
    assigned to.
    */
    struct Admin {
        bool authorized;
        uint id;
    }
    
    /* Assignment Struct handles the assignments given to the studens. the assignmentInfo enum is 
    used to find out if the assignment is active or not and the associated status. Since all assignment
    will have their status as Inactive at first, it can also be used to determine the status of final project.
    The mapping 0 of Assignment Struct for these reasons is reserved as index 0.
    */
    struct Assignment {
        string link; //the github link of the assignment 
        uint8 status; // for the assignment information
    }
    
    /*  Certification of Students can be handled in a struct, proposed solution:
    We use mapping of uint to store id which is mapped to individual students, a 
    reverse function to map that id to student email id is also used to retrieve the student 
    using their email id.
    - firstName - using bytes32 to save space, handles 32 characters 
    - lastName - using bytes32 to save space, handles 32 characters
    - commendation - using bytes32 to save space, handles 32 characters
    - grade - using uint8 since grade is from 1 to 5, max range 256
    - assigmentIndex - using uint16 to handle it, max range 65536 | IMP: 0 is always reserved for Final Project
    - isRemoved - determines if the student has been deemed removed by the admins 
    - email - is used to reverse map for a student and to display email as well
    - assigments - is a mapping of uint16 to struct Assignment
    */
    struct Student {
        bytes32 firstName;
        bytes32 lastName;
        bytes32 commendation;
        
        uint8 grade;
        uint16 assigmentIndex;
        bool active;
        
        string email;
        
        mapping (uint16 => Assignment) assignments;
    }
    
    /* ***************
    * DEFINE VARIABLES
    *************** */
    mapping (address => Admin) public admins;
    mapping (uint => address) public adminsReverseMapping;
    uint public adminIndex;
    uint public maxAdmins; // for setting the max admin limit 
    
    mapping (uint => Student) public students;
    mapping (string => uint) public studentsReverseMapping;
    uint public studentIndex;
    
    /* ***************
    * DEFINE MODIFIERS
    *************** */
    // The modifier restricts function access to only admins or owners
    modifier onlyAdmins() {
        require(
            admins[msg.sender].authorized,
            "Only Admins allowed."
            );
        _;
    }
    
    // The modifier restricts function access to only non-owner admins
    modifier onlyNonOwnerAdmins(address _addr) {
        require(
            admins[_addr].authorized && owner() != _addr,
            "Only Non-Owner Admin allower."
            );
        _;
    }
    
    // The modifier checks the limit of number of Admins allowed
    modifier onlyPermissibleAdminLimit() {
        require(
            adminIndex < maxAdmins,
            "Admins Limit Exceeded"
            );
        _;
    }
    
    // The modifier checks for non-existent students
    modifier onlyNonExistentStudents(string memory _email) {
        require(
            !students[studentsReverseMapping[_email]].active,
            "Student already Exists"
            );
        _;
    }
    
    // The modifier checks for valid students
    modifier onlyValidStudents(string memory _email) {
        require(
            students[studentsReverseMapping[_email]].active,
            "Student doesn't Exists"
            );
        _;
    }
    
    /* ***************
    * DEFINE FUNCTIONS
    *************** */
    constructor () public {
        maxAdmins = 2; // mapping the max number of admins including the owner
        
        // Add Owner as admin
        _addAdmin(msg.sender);
    }
    
    // 1. OVERRIDE OWANABLE FUNCTIONS FOR ADMIN FUNCTIONALITY
    // Remove Previous Admin and Add New Owner if necessary | Overriding Ownable.sol
    function transferOwnership(address newOwner) public onlyOwner {
        // Remove Admin
        _removeAdmin(owner());
        
        // Add New Admin
        _addAdmin(newOwner);
        
        // Call parent
        super._transferOwnership(newOwner);
    }
    
    // 2. ADMIN RELATED FUNCTIONS
    // To Add Administrator
    function addAdmin(address _addr) onlyOwner onlyPermissibleAdminLimit public {
        // call helper function since constructor needs this
        _addAdmin(_addr);
    }
    
    // Private helper function to add administrator
    function _addAdmin(address _addr) private {
        // If Admin doesn't exist alread then add
        if (!admins[_addr].authorized) {
            // Add to admins 
            admins[_addr] = Admin(
                    true,           // authorized value
                    adminIndex      // admin count
                );
                
            // Add to admins info for reverse mapping
            adminsReverseMapping[adminIndex] = _addr;
            
            // Increase admin index
            adminIndex = adminIndex.add(1);
        }
    }
    
    // To Remove Administrator, can't remove an owner address
    function removeAdmin(address _addr) onlyOwner onlyNonOwnerAdmins(_addr) external {
        _removeAdmin(_addr);
    }
    
    // Private helper function to remove administrator
    function _removeAdmin(address _addr) private {
        // check if the admin index is greater than 0
        require(
                adminIndex > 0,
                "Requires atleast 1 Admin."
            );
        
        // a bit tricky, swap and delete to maintain mapping 
        if (admins[_addr].authorized) {
            // get id of the admin to be deleted
            uint swappableId = admins[_addr].id;
            
            // swap the admins info and update admins mapping
            // get the last adminsReverseMapping address for swapping
            address swappableAddress = adminsReverseMapping[adminIndex];
            
            // swap the adminsReverseMapping and then reduce admin index
            adminsReverseMapping[swappableId] = adminsReverseMapping[adminIndex];
            
            // also remap the admins id
            admins[swappableAddress].id = swappableId;
            
            // delete and reduce admin index 
            delete(admins[_addr]);
            delete(adminsReverseMapping[adminIndex]);
            adminIndex = adminIndex.sub(1);
        }
    }
    
    // To Change Administrator Limit
    function changeAdminLimit(uint _newLimit) external {
        require(
            _newLimit >= 1, "Limit >= 1 required"  
        );
        
        maxAdmins = _newLimit;
    }
    
    // 3. STUDENTS RELATED FUNCTIONS
    // To Add Student
    function addStudent(
        bytes32 _firstName,
        bytes32 _lastName,
        bytes32 _commendation,
        uint8 _grade,
        string calldata _email
    )
    external onlyAdmins onlyNonExistentStudents(_email) {
        // Add to students 
        students[studentIndex] = Student(
                _firstName,
                _lastName,
                _commendation,
                _grade,
                0,                  // assigmentIndex always starts with 0
                true,              // active defaults to true          
                _email
            );
        
        // Reverse map for look up based on email
        studentsReverseMapping[_email] = studentIndex;
    }
    
    // To Remove Student
    function removeStudent (string calldata _email) external onlyAdmins onlyValidStudents(_email) {
        // update active status
        students[studentsReverseMapping[_email]].active = false;
    }
    
    // To Change Student Name
    function changeStudentName(
        bytes32 _firstName,
        bytes32 _lastName,
        string calldata _email   
    )
    external onlyAdmins onlyValidStudents(_email) {
        // Update Name
        students[studentsReverseMapping[_email]].firstName = _firstName; 
        students[studentsReverseMapping[_email]].lastName = _lastName; 
    }
    
    // To Change Student commendation
    function changeStudentCommendation(
        bytes32 _commendation,
        string calldata _email   
    )
    external onlyAdmins onlyValidStudents(_email) {
        // Update commendation
        students[studentsReverseMapping[_email]].commendation = _commendation; 
    }
    
    // To Change Student Grade 
    function changeStudentName(
        uint8 _grade,
        string calldata _email   
    )
    external onlyAdmins onlyValidStudents(_email) {
        // Update Grade 
        students[studentsReverseMapping[_email]].grade = _grade; 
    }
    
    // To Change Student Email
    function changeStudentEmail(
        string calldata _oldEmail,
        string calldata _newEmail
    )
    external onlyAdmins onlyValidStudents(_oldEmail) onlyNonExistentStudents(_newEmail) {
        // update emails 
        students[studentsReverseMapping[_oldEmail]].email = _newEmail;
        studentsReverseMapping[_newEmail] = studentsReverseMapping[_oldEmail];
        
        // delete old email
        delete(studentsReverseMapping[_oldEmail]);
    }
    
    // 4. ASSIGNMENT RELATED FUNCTIONS
    
}
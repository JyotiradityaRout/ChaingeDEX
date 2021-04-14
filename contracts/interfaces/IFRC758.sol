// SPDX-License-Identifier: UNLICENSED
// pragma solidity =0.7.6;
pragma solidity =0.5.16;

interface IFRC758 {
    event Transfer(address indexed _from, address indexed _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    // function balanceOf(address _owner) external view returns (uint256[] memory _amount, uint256[] memory _tokenStart, uint256[] memory _tokenEnd);
    function balanceOf(address _owner, uint256 startTime, uint256 endTime)  external view returns (uint256);
    function balanceOfFor(address _owner) external view returns (uint256);
    
    function setApprovalForAll(address _operator, bool _approved) external;
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);

    function transferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd) external;
    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd) external;
    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd, uint256 newTokenStart, uint256 newTokenEnd, bytes calldata _data) external;

    function totalSupply() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256);

   //   function onTimeSlicedTokenReceived(address _operator, address _from, uint256 amount, uint256 newTokenStart, uint256 newTokenEnd, bytes calldata _data) external returns(bytes4);
}

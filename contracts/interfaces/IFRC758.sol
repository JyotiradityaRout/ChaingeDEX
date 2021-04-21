// SPDX-License-Identifier: UNLICENSED
// pragma solidity =0.7.6;
pragma solidity =0.5.16;

interface IFRC758 {
    event Transfer(address indexed _from, address indexed _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _spender);
    function sliceOf(address _owner) external view returns (uint256[] memory, uint256[] memory, uint256[] memory);
    function timeBalanceOf(address _owner, uint256 tokenStart, uint256 tokenEnd) external view returns (uint256);
    function setApprovalForAll(address _spender, bool _approved) external;
    function isApprovedForAll(address _owner, address _spender) external view returns (bool);
    function safeTransferFrom(address _from, address _to, uint256 amount, uint256 tokenStart, uint256 tokenEnd) external;
    function totalSupply() external view returns (uint256);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256);
}
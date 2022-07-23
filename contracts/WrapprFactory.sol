// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import {Multicall, Wrappr} from "./Wrappr.sol";

/// @title Wrappr Factory
/// @author KaliCo LLC
/// @notice Factory to deploy ricardian contracts.
contract WrapprFactory is Multicall {
    event WrapprDeployed(
        address indexed wrappr, 
        string name, 
        string symbol, 
        string baseURI, 
        uint256 mintFee, 
        address indexed admin
    );

    function deployWrappr(
        string calldata _name,
        string calldata _symbol,
        string calldata _baseURI,
        uint256 _mintFee,
        address _admin
    ) external payable {
        address wrappr = address(
            new Wrappr{salt: keccak256(bytes(_name))}(
                _name,
                _symbol,
                _baseURI,
                _mintFee,
                _admin
            )
        );

        emit WrapprDeployed(
            wrappr, 
            _name, 
            _symbol, 
            _baseURI, 
            _mintFee, 
            _admin
        );
    }
}

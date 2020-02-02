const Certifications = artifacts.require("Certifications");

module.exports = function(deployer) {
  deployer.deploy(Certifications);
};

//[assignment] write your own unit test to show that your Mastermind variation circuit is working as expected

const path = require("path");
const chai = require("chai");
const wasm_tester = require("circom_tester").wasm;
const buildPoseidon = require("circomlibjs").buildPoseidon;
const buildBabyJub = require("circomlibjs").buildBabyjub;

const assert = chai.assert;

describe("Mastermind for Kids", function () {
  let circuit;
  let babyJub;
  let F;
  let poseidonHasher;
  
  this.timeout(10000000);

  before( async() => {
      babyJub = await buildBabyJub();
      F = babyJub.F;
      poseidonHasher = await buildPoseidon();
      circuit = await wasm_tester(path.join(__dirname, "../contracts/circuits", "MastermindVariation.circom"));
  });

  console.log("Path: " + __dirname);

  it("Check Mastermind for Kids circuit", async () => {
    // private inputs
    const privSalt = 98765;
    const privSolnA = 0;
    const privSolnB = 2;
    const privSolnC = 0;

    // public inputs
    const pubGuessA = 0;  // red piece (exact match)
    const pubGuessB = 1;  // no match
    const pubGuessC = 2; // white pice (non-exact match)
    const pubNumHit = 1;
    const pubNumBlow = 1;
    const pubSolnHash = F.toObject(poseidonHasher([privSalt, privSolnA, privSolnB, privSolnC])) // equal to output signal

    const input = {
      privSalt: privSalt,
      privSolnA: privSolnA,
      privSolnB: privSolnB,
      privSolnC: privSolnC,
      pubGuessA: pubGuessA,
      pubGuessB: pubGuessB,
      pubGuessC: pubGuessC,
      pubNumHit: pubNumHit,
      pubNumBlow: pubNumBlow,
      pubSolnHash: pubSolnHash
    };
      
    const witness = await circuit.calculateWitness(input, true);

    // witness[1] holds the output to compare
    assert(F.eq(F.e(witness[1]),F.e(pubSolnHash)));
  });

});
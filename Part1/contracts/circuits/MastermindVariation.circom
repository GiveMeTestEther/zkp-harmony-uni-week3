pragma circom 2.0.0;

include "../../node_modules/circomlib/circuits/comparators.circom";
include "../../node_modules/circomlib/circuits/bitify.circom";
include "../../node_modules/circomlib/circuits/poseidon.circom";
// [assignment] implement a variation of mastermind from https://en.wikipedia.org/wiki/Mastermind_(board_game)#Variation as a circuit
include "../../node_modules/circomlib/circuits/mux1.circom";
include "../../node_modules/circomlib/circuits/gates.circom";

// code copdied & adapted from hitandblow.circom

// implementation of: "Mastermind for Kids" https://www.ultraboardgames.com/mastermind/mastermind-for-kids.php

// have 5 animals with a color and map it to a number
// lion: yellow => 0
// bear: green => 1
// elephant : orange => 2
// tiger: blue => 3
// hippo: pink => 4

// 3 holes, no cosntraints on duplicates etc., animals can freely be chosen

// red pieces (hit): animal that is the correct color and in the correct position
// white pieces (blwo): animal that is the correct color, but in an incorrect position 
// same meaning as: animal is in a wrong position, because each animal has a single fixed color

template MastermindVariation() {
    // Public inputs
    signal input pubGuessA;
    signal input pubGuessB;
    signal input pubGuessC;
    signal input pubNumHit;
    signal input pubNumBlow;
    signal input pubSolnHash;

    // Private inputs
    signal input privSolnA;
    signal input privSolnB;
    signal input privSolnC;
    signal input privSalt;

    // Output
    signal output solnHashOut;

    var holes = 3;
    var lessThanNumb = 5;

    var guess[holes] = [pubGuessA, pubGuessB, pubGuessC];
    var soln[holes] =  [privSolnA, privSolnB, privSolnC];

    component lessThan[2 * holes];

    // Create a constraint that the solution and guess digits are all less than 5.
    for (var j=0; j<holes; j++) {
        lessThan[j] = LessThan(3);
        lessThan[j].in[0] <== guess[j];
        lessThan[j].in[1] <== lessThanNumb;
        lessThan[j].out === 1;
        lessThan[j+holes] = LessThan(3);
        lessThan[j+holes].in[0] <== soln[j];
        lessThan[j+holes].in[1] <== lessThanNumb;
        lessThan[j+holes].out === 1;
    }

    // Count hit (red pieces)
    var hit = 0;
    component redPieces[holes];
    for (var i = 0; i < holes; i++){
      redPieces[i] = IsEqual();
      redPieces[i].in[0] <== guess[i];
      redPieces[i].in[1] <== soln[i];
      hit += redPieces[i].out;
    }

    // check white pieces
    component matches[holes][holes];
    component multiOR[holes];
    component whitePieces[holes];
    var blow = 0;

    for (var i = 0; i < holes; i++){ // i iterates over guess
      multiOR[i] = MultiOR(holes);
      for (var j = 0; j < holes; j++){ // j iteartes over soln
        if (i != j){
          matches[i][j] = IsEqual();
          matches[i][j].in[0] <== soln[j];
          matches[i][j].in[1] <== guess[i];
          multiOR[i].in[j] <== matches[i][j].out; // we are or'ing the matches to figure out if any non-exact macthes exist
        } else {
          multiOR[i].in[j] <== 0; // set element i=j to 0, bcs we only check for non-exact matches
        }
      }

      // if there is an exact match, set it to zero, else set it to the outcome of multiOR[i].out
      whitePieces[i] = Mux1();
      whitePieces[i].c[0] <== multiOR[i].out;
      whitePieces[i].c[1] <== 0 ;
      whitePieces[i].s <== redPieces[i].out;
      blow += whitePieces[i].out;
  }

    // Create a constraint around the number of hit
    component equalHit = IsEqual();
    equalHit.in[0] <== pubNumHit;
    equalHit.in[1] <== hit;
    equalHit.out === 1;
    
    // Create a constraint around the number of blow
    component equalBlow = IsEqual();
    equalBlow.in[0] <== pubNumBlow;
    equalBlow.in[1] <== blow;
    equalBlow.out === 1;

    // Verify that the hash of the private solution matches pubSolnHash
    component poseidon = Poseidon(holes + 1);
    poseidon.inputs[0] <== privSalt;
    poseidon.inputs[1] <== privSolnA;
    poseidon.inputs[2] <== privSolnB;
    poseidon.inputs[3] <== privSolnC;

    solnHashOut <== poseidon.out;
    pubSolnHash === solnHashOut;
 }

 template MultiOR(n) {
    signal input in[n];
    signal output out;

    component or1;
    component or2;
    component ors[2];
    if (n==1) {
        out <== in[0];
    } else if (n==2) {
        or1 = OR();
        or1.a <== in[0];
        or1.b <== in[1];
        out <== or1.out;
    } else {
        or2 = OR();
        var n1 = n\2;
        var n2 = n-n\2;
        ors[0] = MultiOR(n1);
        ors[1] = MultiOR(n2);
        var i;
        for (i=0; i<n1; i++) ors[0].in[i] <== in[i];
        for (i=0; i<n2; i++) ors[1].in[i] <== in[n1+i];
        or2.a <== ors[0].out;
        or2.b <== ors[1].out;
        out <== or2.out;
    }
}

 component main {public [pubGuessA, pubGuessB, pubGuessC, pubNumHit, pubNumBlow, pubSolnHash]} = MastermindVariation();
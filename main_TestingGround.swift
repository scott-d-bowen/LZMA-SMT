//  LZMA-TestingGround
//  Created by SDBX on 21/7/2023.

import Foundation                   // Req'd for Data Type.

print("Hello, World!")

// Create an 'Empty' Data Object.
var GLOBAL_DATA: Data = Data();

// Get 16 bytes of 'sorted' random byte values.
// This ensures that the resulting output WILL compress (slightly).
func makeSubBlock() -> [UInt8] {
    var semiRandomSorted: [UInt8] = Array(repeating: 0x00, count: 16);
    for rng in 0..<semiRandomSorted.count {
        semiRandomSorted[rng] = UInt8.random(in: 0x00...0xFF);
    }
    semiRandomSorted.sort()
    return semiRandomSorted;
}

// Create 1MB of semi-sorted random data
// Expect it to compress by ~20% to 25%.
for _ in 0..<1*1024*1024/16 {
    GLOBAL_DATA.append(contentsOf: makeSubBlock());
}

// Check the Size of GLOBAL_DATA
print(GLOBAL_DATA);

// Attempt LZMA compression:
let compTry = try NSData(data: GLOBAL_DATA).compressed(using: .lzma);

// Check the output has changed in size:
print(compTry);

// Calculate 'how much' we need to pad by
// This is just 16 minus the MOD'.
// i.e. 16 minus MOD of 5 is 16 - 5 = +11 bytes to pad by.
let paddDiff = 16 - (compTry.length % 16);
print("Padding by: +\(paddDiff)");

// Turn those NSData Objects into regular Data/Buffer Objects.
var paddedLZMACompData = Data(compTry);
// Create a Data Object of all 0x00's that is the correct length.
let paddDiffData = Data(repeating: 0x00, count: paddDiff);

// TO PAD, OR NOT TO PAD:
//  * That is why we commment out the line below...
//  * If we do this it'll throw (catch below), but I may know a solution already...
// paddedLZMACompData.append(paddDiffData);

// Visually confirm that MOD 16 leaves 0 remainder: (size + true or false).
print(paddedLZMACompData, "; Padded:", paddedLZMACompData.count % 16 == 0);

// Then we reverse the process, and check if the data matches!
do {
    let uncompTry = try Data(referencing: (paddedLZMACompData as NSData).decompressed(using: .lzma));
    print(uncompTry);
    print("matchesByteForByte:", matchesByteForByte(GLOBAL_DATA, uncompTry))
} catch {
    print("FAILED DECOMPRESSION:\n", error);
}

// Utility function that compares two input Data Objects match
// IF they are the same input length to begin with!
func matchesByteForByte(_ inputA: Data, _ inputB: Data) -> Bool {
    guard inputA.count == inputB.count else {
        return false;       // guard against the case where the input
                            // lengths are mismatched.
    }
    for cmp in 0..<inputA.count {
        if !(inputA[cmp] == inputB[cmp]) {
            return false;   // This will 'break' out of the loop
                            // without using the 'break' keyword.
        }
    }
    return true;            // If the comparison loop completes,
                            // then we return 'true'.
}

// If we get this far then it means our 'app' completed all the 'main sync' code (above).
print("Goodbye.")

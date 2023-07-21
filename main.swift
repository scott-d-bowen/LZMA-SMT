//  LZMA-SMT
//  Created by SDBX on 21/7/2023.

import Foundation       // (Needed for Basic DataTypes)
// import Compression   // Might not actually be REQUIRED.

var GLOBAL_ANSI_TIMER = Date()

// let CPU_INFO_NAME = System...;
let CPU_CORE_COUNT_PHYS = System.physicalCores();
let CPU_CORE_COUNT_LOGI = System.logicalCores();

let GLOBAL_COMP_ALG = NSData.CompressionAlgorithm.lzma;

func getAlgorithmName(lookUp: NSData.CompressionAlgorithm) -> String {
    if (lookUp == NSData.CompressionAlgorithm.lz4) { return "LZ4" };
    if (lookUp == NSData.CompressionAlgorithm.lzma) { return "LZMA" };
    if (lookUp == NSData.CompressionAlgorithm.lzfse) { return "LZFSE" };
    if (lookUp == NSData.CompressionAlgorithm.zlib) { return "ZLIB" };
    return "Unknown (Compression?) Algorithm"
}

let BLOCK_SIZE = 1 * 1024 * 1024;           // Reduce to 1MB so we can use 16-byte alignment
var GLOBAL_TALLY_OUTPUT_SIZE: [UInt?];      //  by using just a 16-bit length offset in the
var GLOBAL_START_TIME: Date;                //  written output file. (When we get around to that!).

print("Hello, World!")

GLOBAL_START_TIME = Date();

let inputFile: String = "/Users/sdbx_admin/Downloads/ubuntu-23.04-desktop-legacy-amd64.iso";
let inputURL : URL = URL(fileURLWithPath: inputFile)

// print(inputURL) [OK].


// print("Using:", CPU_INFO_NAME);
print("Input:", inputURL.lastPathComponent);
print("\nProcessing file using \(BLOCK_SIZE/1024)KB block size (per thread)")
print("  using 'up to' \(CPU_CORE_COUNT_LOGI) simultaneous threads")
print("  using 'up to' \(CPU_CORE_COUNT_PHYS) physical CPU cores")
print("  for: \(CPU_CORE_COUNT_LOGI * (BLOCK_SIZE/1024))KB of data in flight at any one time.");


func compressData(inputData: Data) -> Data? {
    var retData: Data? = nil;
    do {
        // Output length 'newSize' should always fit within 3x8-bits.
        let compNSData = try NSData(data: inputData).compressed(using: GLOBAL_COMP_ALG);
        retData = Data(referencing: compNSData);
    } catch {
        print("It Broke!:\n", error)
    }
    return retData;
}

func readUpTo__of_BLOCK_SIZE(inputURL: URL, fromOffset: Int) -> Data? { // Do I want to do this Async?
    var dataBlock: Data? = nil
    let range: Range<Int> = fromOffset..<fromOffset+(BLOCK_SIZE);
    do {
        let safetyDanceA: Int = fileSpecs.currentFileSize! % BLOCK_SIZE; // Runt Length.
        let safetyDanceB: Int = fileSpecs.currentFileSize! - fromOffset; // Length Remaining.
        if (safetyDanceB >= BLOCK_SIZE) {
            dataBlock = try Data(contentsOf: inputURL, options: .mappedIfSafe).subdata(in: range);
        } else if (safetyDanceB < BLOCK_SIZE) {
            let saferRange: Range<Int> = fromOffset..<fromOffset+(safetyDanceA);
            dataBlock = try Data(contentsOf: inputURL, options: .mappedIfSafe).subdata(in: saferRange);
        }
    } catch {
        print("It Broke!:\n", error)
    }
    return dataBlock;
}

func calcBlocks__of_BLOCK_SIZE(inputURL: URL) -> (currentFileSize: Int?, blocks__of_BLOCK_SIZE: Int, blocksRuntSizeBytes: Int) {
    var currentFileSize: Int? = nil;
    do {
        currentFileSize = try Data(contentsOf: inputURL, options: .mappedIfSafe).count
    } catch {
        print("It Broke!:\n", error)
    }
    print("\nCurrent Filesize is:", currentFileSize! / 1024, "KB.")
    let blocks__of_BLOCK_SIZE = currentFileSize! / BLOCK_SIZE;
    let blocksRuntSizeBytes = currentFileSize! % (BLOCK_SIZE);
    print("Which is \(blocks__of_BLOCK_SIZE) x \(BLOCK_SIZE/1024)KB blocks");
    if (blocksRuntSizeBytes >= 1024) {
        print("  plus a \(blocksRuntSizeBytes / 1024) KB runt at the end.");
    } else if (blocksRuntSizeBytes < 1024) {
        print("  plus a \(blocksRuntSizeBytes) byte runt at the end.");
    }
    return (currentFileSize, blocks__of_BLOCK_SIZE, blocksRuntSizeBytes);
}

let (fileSpecs) = calcBlocks__of_BLOCK_SIZE(inputURL: inputURL);
// [OK]: print(fileSpecs)

// Do we tell a lie?:
let doWeTellALie = fileSpecs.blocksRuntSizeBytes > 0 ?
    fileSpecs.blocks__of_BLOCK_SIZE + 1 :
    fileSpecs.blocks__of_BLOCK_SIZE;

// Get the Output Size in Order:
//  * Each output has 3-4 bytes of overhead to measure its size (so we can reverse the process).
GLOBAL_TALLY_OUTPUT_SIZE = Array(repeating: nil, count: doWeTellALie); // [OK].

/* if (fileSpecs.blocksRuntSizeBytes > 0) {
    fileSpecs.blocks__of_BLOCK_SIZE += 1;   // Here we 'did' tell a 'lie'. (For testing breaking of funcs).
} */

func mainProcess() {
    print("\nInitializing Main Process...")
    print("Using Algorithm:", getAlgorithmName(lookUp: GLOBAL_COMP_ALG)); // TODO: SDBX
    print();
    // for idxGCD in 0..<fileSpecs.blocks__of_BLOCK_SIZE {
    DispatchQueue.concurrentPerform(iterations: doWeTellALie, execute: { idxGCD in
        autoreleasepool(invoking: {
            let fromOffset = idxGCD * BLOCK_SIZE;
            let currBlock = readUpTo__of_BLOCK_SIZE(inputURL: inputURL, fromOffset: fromOffset)
            // [OK]: print("r", terminator: "");
            let compBlock = compressData(inputData: currBlock!);
            // [OK]: print("c", terminator: "");
            // [OK]: print(": Block#\(idxGCD+1)", compBlock!.count, "bytes out.")
            if (compBlock!.count > BLOCK_SIZE) {
                // [OK]: print("  : Block#\(idxGCD+1)", compBlock!.count, "FAILED TO SHRINK.")
                GLOBAL_TALLY_OUTPUT_SIZE[idxGCD] = UInt(BLOCK_SIZE);
            } else {
                if (compBlock != nil) {
                    let cannotOneLineThis__ = ((compBlock!.count));
                    GLOBAL_TALLY_OUTPUT_SIZE[idxGCD] = (UInt(cannotOneLineThis__));
                }
            }
            // [Not really needed]: if (idxGCD > 0 && idxGCD % 32 == 0) { print(); }
        }) // END: AUTORELPOOL
        // print("\u{001B}[2K"); // STD ANSI CODE 'TRICK' TO CLEAR LINE (ESC+[2K).
        if (idxGCD % CPU_CORE_COUNT_LOGI == 0) {
            if (-GLOBAL_ANSI_TIMER.timeIntervalSinceNow >= 3.0) {
                GLOBAL_ANSI_TIMER = Date();
                // print("\u{001B}[2K", terminator: ""); // Erase Existing Line.
                // print("\r", terminator: ""); // Just a simple 'CR'. (Ed: without a terminator!).
                print("Processed \((idxGCD+1)*BLOCK_SIZE/1024)KB."); // Also, without a terminator!? [soon...]
            }
        }
    }) // END: GCD
    print(); print("Main Process (GCD) Complete."); print();
}
mainProcess();

func tallyTotalSumOutputFileSize() -> UInt64 {
    var outputSize: UInt64 = 0;
    for rollingSum in 0..<GLOBAL_TALLY_OUTPUT_SIZE.count {
        if (GLOBAL_TALLY_OUTPUT_SIZE[rollingSum] == nil) {
            print(" * Rolling Tally \(rollingSum) was 'nil'.")
        } else {
            outputSize += UInt64(GLOBAL_TALLY_OUTPUT_SIZE[rollingSum]!);
        }
    }
    return outputSize;
}

// Measure the Specs for Performance, etc:
let totalApxOutputSize = tallyTotalSumOutputFileSize();
let GLOBAL_FINISH_TIMEINT: TimeInterval = -GLOBAL_START_TIME.timeIntervalSinceNow;

// Output Results:
print("Output Compressed Data Size (in bytes) is:", totalApxOutputSize);
print(" * This excludes any overheads...");

print()

func printStatsSummary() {
    print("Read in        :", fileSpecs.currentFileSize!, "bytes.")
    print("Compressed out :", totalApxOutputSize, "bytes.")
    print("Time Taken     :", GLOBAL_FINISH_TIMEINT, "seconds.")
    print("Speed (KB/sec) :", Double(fileSpecs.currentFileSize!) / 1024.0 / GLOBAL_FINISH_TIMEINT, "KB/sec.")
    let compRatio = Double(fileSpecs.currentFileSize!) / Double(totalApxOutputSize);
    print("Comprssn Ratio :", compRatio);
    print("Output Smaller :", totalApxOutputSize < fileSpecs.currentFileSize!);
}
printStatsSummary();

print("Goodbye.")
sleep(60);             // So I can witness the attached Debugger.

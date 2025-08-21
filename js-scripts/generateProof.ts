import { Noir } from "@noir-lang/noir_js";
import { ethers } from "ethers";
import { UltraHonkBackend } from "@aztec/bb.js";
import { fileURLToPath} from "url";
import path from "path";
import fs from "fs";

// get the circuit file with the bytecode
const circuitPath = path.resolve(path.dirname(fileURLToPath(import.meta.url)),
"../../circuits/target/zk_panagram.json");
const circuit = JSON.parse(fs.readFileSync(circuitPath, "utf8"));

export default async function generateProof() {
    const inputsArray = process.argv.slice(2);
    try {
        // initialize Noir with the circuit
        const noir = new Noir(circuit);
        // initialize the backend using the circuit bytecode
        const bb = new UltraHonkBackend(circuit.bytecode, {threads: 1});
        // create the inputs
        const inputs = {
            // Private inputs
            guess_hash: inputsArray[0],
            // Public inputs
            answer_hash: inputsArray[1],
            address: inputsArray[2],
        }
        // Execute the circuit with the inputs to create the witness
        const {witness} = await noir.execute(inputs);
        // Generate the proof (using the backend) with the witness
        const originalLog = console.log;
        console.log = () => {};
        const {proof} = await bb.generateProof(witness, {keccak: true});
        console.log = originalLog;
        // ABI encode proof to return it in a format that can be used in the test
        const proofEncoded = ethers.AbiCoder.defaultAbiCoder().encode(
            ["bytes"],
            [proof]
        )
        // return the proof
        return proofEncoded;
    } catch(error) {
        console.log(error);
        throw error;
    }
}

(async () => {
    generateProof()
        .then((proof) => {
            process.stdout.write(proof);
            process.exit(0);
        })
        .catch((error) => {
            console.log(error);
            process.exit(1);
        })
})();
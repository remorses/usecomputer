import readline from "node:readline/promises";

/**
 * Takes a user input from terminal and returns a string
 * or returns a valid number or NaN if the conversion is not successful
 * @param {string} [prompt=] - the prompt message to display to the user
 * @param {{to: "int" | "float"}} [options=] - Converts the input to int or float
 * @returns {Promise<string | number>}
 * @example
 * const name = await input("What is your name? ") // joe
 * console.log(name) //--> joe
 */
export async function input(prompt = "", opts = { to: "int" | "float" }) {
	const rl = readline.createInterface({
		input: process.stdin,
		output: process.stdout,
	});

	const result = await rl.question(prompt);
	rl.close();

	switch (opts.to) {
		case "int":
			return Number.parseInt(result);
		case "float":
			return Number.parseFloat(result);
		default:
			return result;
	}
}

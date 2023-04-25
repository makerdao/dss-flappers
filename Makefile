all   :; FOUNDRY_OPTIMIZER=true FOUNDRY_OPTIMIZER_RUNS=200 forge build --use solc:0.8.16
clean :; forge clean
test  :; ./test.sh $(match)

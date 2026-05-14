def fact_of_fact(n):
	if n < 1:
		return 1

	product = 1
	fact = 1

	for i in range(1, n + 1):
		fact *= i
		product *= fact
	return product

# Test Cases    
n = int(input("Veuillez entrer un nombre: "))
print(fact_of_fact(n))
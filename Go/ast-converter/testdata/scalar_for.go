package main

func main() {
	// Векторы как массивы длины 4
	a := [4]int{1, 2, 3, 4}
	b := [4]int{5, 6, 7, 8}

	// Скалярное произведение через цикл
	result := 0
	for i := 0; i < 4; i++ {
		result = result + a[i]*b[i]
	}

	// Ожидаемый результат: 70
	_ = result
}

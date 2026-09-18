package main

func main() {
	x := 5

	// Простой if
	if x > 3 {
		x = 10
	}

	// if-else
	if x > 3 {
		x = 10
	} else {
		x = 20
	}

	// if-else if-else
	if x > 10 {
		x = 1
	} else if x > 5 {
		x = 2
	} else {
		x = 3
	}

	// if с init
	if y := x * 2; y > 10 {
		x = y
	}

	_ = x
}

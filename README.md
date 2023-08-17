##### build

```
cd "$(dirname "$0")"
cd ./

xcrun -sdk macosx metal -c default.metal -o ./default.air; xcrun -sdk macosx metallib ./default.air -o ./default.metallib; rm ./default.air
clang++ -std=c++20 -Wc++20-extensions -fobjc-arc -O3 -framework Cocoa -framework Metal -framework QuartzCore ./main.mm -o ./main
./main
```
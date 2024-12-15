# Conversão de JPEG para tons de cinza em CUDA

Experimento de processamento de imagem que usa a GPU para converter pixels para tons de cinza. [main.cu](main.cu) lê um JPEG colorido com libjpeg, passa os pixels a um kernel CUDA e grava lotes de 1, 10, 100 e 1.000 arquivos. Cada lote usa a mesma imagem de origem.

## Como executar

Use CMake 3.29 ou superior, libjpeg, CUDA Toolkit com suporte a C++17, compilador anfitrião compatível e uma GPU NVIDIA. A partir da raiz:

```bash
cmake -S . -B build
cmake --build build --config Release
```

Com vcpkg, configure o CMake com `-DCMAKE_TOOLCHAIN_FILE="CAMINHO_DO_VCPKG/scripts/buildsystems/vcpkg.cmake"` e disponibilize libjpeg para a arquitetura de compilação.

Execute o alvo `DataSetGrey_Cuda` na raiz do repositório. Com Visual Studio, procure `build/Release/DataSetGrey_Cuda.exe`. O programa usa `Imagens/IMAGEM.jpg` como entrada e `Imagens` como diretório de saída. Para usar outros caminhos, forneça o JPEG e a pasta de saída como primeiro e segundo argumentos. A entrada precisa ter três canais e dimensões mínimas de 500 × 500. A saída fica em pastas `out_1`, `out_10`, `out_100` e `out_1000`. Os tempos por lote incluem transferências de dados e gravação de JPEGs.

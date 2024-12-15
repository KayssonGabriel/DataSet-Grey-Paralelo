# Definir a versão mínima do CMake
cmake_minimum_required(VERSION 3.29)

# Nome do projeto
project(DataSetGrey_Cuda LANGUAGES CXX CUDA)

# Definir o padrão C++17 e CUDA 11
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 11)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

# Configurar o Vcpkg
set(CMAKE_TOOLCHAIN_FILE "C:/Users/kayss/vcpkg/scripts/buildsystems/vcpkg.cmake")

# Habilitar suporte à linguagem CUDA
enable_language(CUDA)

# Adicionar o arquivo fonte principal
add_executable(DataSetGrey_Cuda main.cu)

# Encontrar e linkar a biblioteca JPEG
find_package(JPEG REQUIRED)
target_link_libraries(DataSetGrey_Cuda PRIVATE JPEG::JPEG)

# Adicionar flags de compilação para debug
if (CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(DataSetGrey_Cuda PRIVATE
            $<$<COMPILE_LANGUAGE:CUDA>:--generate-line-info>
            $<$<COMPILE_LANGUAGE:CXX>:-g>
    )
endif()

# Certificar-se de que o projeto utiliza C++17
target_compile_features(DataSetGrey_Cuda PRIVATE cxx_std_17)

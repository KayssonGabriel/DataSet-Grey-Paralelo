#include <iostream>
#include <vector>
#include <string>
#include <cuda_runtime.h>
#include <jpeglib.h>
#include <chrono>
#include <filesystem>
#include <memory>
#include <stdexcept>

namespace fs = std::filesystem;

// Kernel CUDA para converter uma imagem para tons de cinza
__global__ void convertToGrayscaleKernel(unsigned char* image, int rows, int cols)
{
    int j = blockIdx.x * blockDim.x + threadIdx.x;
    int i = blockIdx.y * blockDim.y + threadIdx.y;

    if (i < rows && j < cols)
    {
        unsigned char* pixel = &image[(i * cols + j) * 3];
        unsigned char red = pixel[0];
        unsigned char green = pixel[1];
        unsigned char blue = pixel[2];

        unsigned char gray = static_cast<unsigned char>(red * 0.298 + green * 0.587 + blue * 0.114);

        pixel[0] = gray;
        pixel[1] = gray;
        pixel[2] = gray;
    }
}

// Função para ler uma imagem JPEG
bool readJPEG(const std::string& filename, std::vector<unsigned char>& image, int& rows, int& cols)
{
    FILE* infile = fopen(filename.c_str(), "rb");
    if (!infile)
    {
        std::cerr << "Could not open file: " << filename << std::endl;
        return false;
    }

    struct jpeg_decompress_struct cinfo;
    struct jpeg_error_mgr jerr;

    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_decompress(&cinfo);
    jpeg_stdio_src(&cinfo, infile);
    jpeg_read_header(&cinfo, TRUE);
    jpeg_start_decompress(&cinfo);

    rows = cinfo.output_height;
    cols = cinfo.output_width;
    int channels = cinfo.output_components;

    if (channels != 3)
    {
        std::cerr << "Unsupported number of channels: " << channels << " in file: " << filename << std::endl;
        jpeg_destroy_decompress(&cinfo);
        fclose(infile);
        return false;
    }

    image.resize(rows * cols * 3); // Redimensiona a imagem para armazenar os pixels
    unsigned char* row_pointer = new unsigned char[cols * channels];
    while (cinfo.output_scanline < cinfo.output_height)
    {
        int row = cinfo.output_scanline;
        jpeg_read_scanlines(&cinfo, &row_pointer, 1);
        for (int col = 0; col < cols; ++col)
        {
            image[(row * cols + col) * 3 + 0] = row_pointer[col * channels];
            image[(row * cols + col) * 3 + 1] = row_pointer[col * channels + 1];
            image[(row * cols + col) * 3 + 2] = row_pointer[col * channels + 2];
        }
    }

    delete[] row_pointer;
    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);
    fclose(infile);
    return true;
}

// Função para salvar uma imagem JPEG
void saveJPEG(const std::string& filename, const std::vector<unsigned char>& image, int rows, int cols)
{
    FILE* outfile = fopen(filename.c_str(), "wb");
    if (!outfile)
    {
        std::cerr << "Could not open file for writing: " << filename << std::endl;
        return;
    }

    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;

    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);
    jpeg_stdio_dest(&cinfo, outfile);

    cinfo.image_width = cols;
    cinfo.image_height = rows;
    cinfo.input_components = 3;
    cinfo.in_color_space = JCS_RGB;

    jpeg_set_defaults(&cinfo);
    jpeg_set_quality(&cinfo, 85, TRUE);
    jpeg_start_compress(&cinfo, TRUE);

    unsigned char* row_pointer = new unsigned char[cols * 3];
    while (cinfo.next_scanline < cinfo.image_height)
    {
        int row = cinfo.next_scanline;
        for (int col = 0; col < cols; ++col)
        {
            row_pointer[col * 3] = image[(row * cols + col) * 3 + 0];
            row_pointer[col * 3 + 1] = image[(row * cols + col) * 3 + 1];
            row_pointer[col * 3 + 2] = image[(row * cols + col) * 3 + 2];
        }
        jpeg_write_scanlines(&cinfo, &row_pointer, 1);
    }

    delete[] row_pointer;
    jpeg_finish_compress(&cinfo);
    jpeg_destroy_compress(&cinfo);
    fclose(outfile);
}

void verificarCuda(cudaError_t status, const char* operacao)
{
    if (status != cudaSuccess) {
        throw std::runtime_error(std::string(operacao) + ": " + cudaGetErrorString(status));
    }
}

int main(int argc, char* argv[]) try
{
    const std::string image_path = argc > 1 ? argv[1] : "Imagens/IMAGEM.jpg";
    const fs::path output_root = argc > 2 ? argv[2] : "Imagens";
    auto start_time = std::chrono::high_resolution_clock::now();

    // Ler a imagem original
    int rows, cols;
    std::vector<unsigned char> image;
    if (!readJPEG(image_path, image, rows, cols))
    {
        return 1;
    }

    if (rows < 500 || cols < 500)
    {
        std::cerr << "Imagem menor que 500x500: " << image_path << std::endl;
        return 1;
    }

    // Definir os intervalos de diretórios
    std::vector<int> quantities = {1, 10, 100, 1000};
    for (int quantity : quantities)
    {
        // Marcar o tempo para cada quantidade
        auto start_interval_time = std::chrono::high_resolution_clock::now();

        // Criar diretório de saída
        const fs::path output_directory = output_root / ("out_" + std::to_string(quantity));
        fs::create_directories(output_directory);

        unsigned char* d_image = nullptr;
        verificarCuda(cudaMalloc(&d_image, image.size()), "alocar imagem na GPU");
        std::unique_ptr<unsigned char, decltype(&cudaFree)> buffer(d_image, cudaFree);

        // Configuração dos blocos e threads
        dim3 threadsPerBlock(16, 16);
        dim3 numBlocks((cols + 15) / 16, (rows + 15) / 16);

        // Processar e salvar as imagens
        for (int i = 0; i < quantity; ++i)
        {
            verificarCuda(cudaMemcpy(d_image, image.data(), image.size(), cudaMemcpyHostToDevice), "enviar imagem");
            convertToGrayscaleKernel<<<numBlocks, threadsPerBlock>>>(d_image, rows, cols);
            verificarCuda(cudaGetLastError(), "lançar conversão CUDA");

            std::vector<unsigned char> image_copy(image.size());
            verificarCuda(cudaMemcpy(image_copy.data(), d_image, image.size(), cudaMemcpyDeviceToHost), "receber imagem");

            const fs::path output_path = output_directory / ("IMAGEM_" + std::to_string(i + 1) + "_converted.jpg");
            saveJPEG(output_path.string(), image_copy, rows, cols);
        }

        auto end_interval_time = std::chrono::high_resolution_clock::now();
        std::chrono::duration<double> interval_elapsed_time = end_interval_time - start_interval_time;
        std::cout << "Tempo para " << quantity << " imagens: " << interval_elapsed_time.count() << " segundos" << std::endl;
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> elapsed_time = end_time - start_time;
    std::cout << "Tempo total: " << elapsed_time.count() << " segundos" << std::endl;

    return 0;
} catch (const std::exception& erro) {
    std::cerr << erro.what() << std::endl;
    return 1;
}

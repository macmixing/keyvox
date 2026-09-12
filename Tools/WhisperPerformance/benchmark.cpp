#include <whisper.h>
#include "../WhisperEncoder/include/keyvox-whisper-encoder.h"
#include <chrono>
#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>
#include <cstdlib>

using Clock = std::chrono::steady_clock;
static double milliseconds(Clock::time_point start) {
    return std::chrono::duration<double, std::milli>(Clock::now() - start).count();
}

// Caller-provided audio only: mono 16 kHz little-endian Float32 PCM.
int main(int argc, char **argv) {
    if (argc != 7 && argc != 10) return 2;
    const int threads = std::atoi(argv[3]);
    const bool gpu = std::atoi(argv[4]) != 0;
    const int repeats = std::atoi(argv[5]);
    if (threads < 1 || threads > 32 || repeats < 1 || repeats > 20) return 2;
    std::ifstream input(argv[2], std::ios::binary | std::ios::ate);
    if (!input) return 3;
    const auto size = input.tellg();
    if (size <= 0 || size % sizeof(float) != 0) return 3;
    std::vector<float> frames(size / sizeof(float));
    input.seekg(0);
    if (!input.read(reinterpret_cast<char *>(frames.data()), size)) return 3;
    auto context_params = whisper_context_default_params();
    context_params.use_gpu = gpu;
    auto start = Clock::now();
    auto *context = whisper_init_from_file_with_params(argv[1], context_params);
    if (!context) return 4;
    std::cout << "KV_LOAD ms=" << milliseconds(start) << " threads=" << threads
              << " gpu_requested=" << gpu << " frames=" << frames.size() << std::endl;
    if (argc == 10) {
        start = Clock::now();
        const bool configured = keyvox_whisper_load_encoder(context, argv[7], argv[8], argv[9]);
        std::cout << "KV_ENCODER configured=" << configured << " setup_ms=" << milliseconds(start) << std::endl;
    }
    auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = threads;
    // Explicit caller choice, including Whisper's automatic detection mode.
    params.language = argv[6];
    params.no_context = true;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.suppress_blank = true;
    params.suppress_nst = true;
    params.temperature = 0.0f;
    params.temperature_inc = 0.0f;
    params.no_speech_thold = 0.6f;
    params.logprob_thold = -0.8f;
    for (int run = 0; run < repeats; ++run) {
        whisper_reset_timings(context);
        start = Clock::now();
        int status = whisper_full(context, params, frames.data(), frames.size());
        if (status != 0) { whisper_free(context); return 5; }
        const auto *timings = whisper_get_timings(context);
        std::cout << "KV_RUN index=" << run << " total_ms=" << milliseconds(start)
                  << " average_encode_ms=" << timings->encode_ms << " average_decode_ms=" << timings->decode_ms
                  << " average_prompt_ms=" << timings->prompt_ms << " average_sample_ms=" << timings->sample_ms << std::endl;
        delete timings;
        whisper_print_timings(context);
        std::cout << "KV_TEXT ";
        for (int i = 0; i < whisper_full_n_segments(context); ++i) std::cout << whisper_full_get_segment_text(context, i);
        std::cout << std::endl;
    }
    whisper_free(context);
}

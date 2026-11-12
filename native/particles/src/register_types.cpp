#include "coin_noise_kernel.hpp"
#include "particle_kernel.hpp"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>

namespace {

void initialize(godot::ModuleInitializationLevel level) {
    if (level == godot::MODULE_INITIALIZATION_LEVEL_SCENE) {
        GDREGISTER_CLASS(TavernParticleKernel);
        GDREGISTER_CLASS(TavernCoinNoiseKernel);
    }
}

void uninitialize(godot::ModuleInitializationLevel) {}

} // namespace

extern "C" GDExtensionBool GDE_EXPORT tavern_native_particles_init(
        GDExtensionInterfaceGetProcAddress get_proc_address,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    godot::GDExtensionBinding::InitObject binding(get_proc_address, library, initialization);
    binding.register_initializer(initialize);
    binding.register_terminator(uninitialize);
    binding.set_minimum_library_initialization_level(godot::MODULE_INITIALIZATION_LEVEL_SCENE);
    return binding.init();
}

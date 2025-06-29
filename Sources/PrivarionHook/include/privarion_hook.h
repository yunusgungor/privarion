#ifndef PRIVARION_HOOK_H
#define PRIVARION_HOOK_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>

// Version information
#define PRIVARION_HOOK_VERSION_MAJOR 1
#define PRIVARION_HOOK_VERSION_MINOR 0
#define PRIVARION_HOOK_VERSION_PATCH 0

// Error codes
typedef enum {
    PH_SUCCESS = 0,
    PH_ERROR_INVALID_PARAM = -1,
    PH_ERROR_FUNCTION_NOT_FOUND = -2,
    PH_ERROR_ALREADY_HOOKED = -3,
    PH_ERROR_NOT_HOOKED = -4,
    PH_ERROR_MEMORY_ERROR = -5,
    PH_ERROR_PERMISSION_DENIED = -6,
    PH_ERROR_UNSUPPORTED_PLATFORM = -7
} PHResult;

// Hook entry structure
typedef struct PHookEntry {
    char function_name[256];
    void* original_function;
    void* replacement_function;
    bool is_active;
    struct PHookEntry* next;
} PHookEntry;

// Hook handle for managing individual hooks
typedef struct {
    uint32_t id;
    char function_name[256];
    bool is_valid;
} PHookHandle;

// Core Hook Management Functions
/**
 * Initialize the hook system
 * Must be called before any other hook operations
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_initialize(void);

/**
 * Cleanup and shutdown the hook system
 * Removes all active hooks and frees resources
 */
void ph_cleanup(void);

/**
 * Install a hook for a specific function
 * @param function_name Name of the function to hook
 * @param replacement_function Pointer to replacement function
 * @param handle Output parameter for hook handle
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_install_hook(const char* function_name, 
                        void* replacement_function,
                        PHookHandle* handle);

/**
 * Remove a previously installed hook
 * @param handle Handle of the hook to remove
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_remove_hook(const PHookHandle* handle);

/**
 * Get pointer to original function
 * @param handle Handle of the hook
 * @return Pointer to original function, NULL if not found
 */
void* ph_get_original(const PHookHandle* handle);

/**
 * Check if a function is currently hooked
 * @param function_name Name of the function to check
 * @return true if hooked, false otherwise
 */
bool ph_is_hooked(const char* function_name);

// System Call Specific Functions
/**
 * Hook the uname system call
 * @param replacement Replacement function pointer
 * @param handle Output parameter for hook handle
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_hook_uname(void* replacement, PHookHandle* handle);

/**
 * Hook the gethostname system call
 * @param replacement Replacement function pointer
 * @param handle Output parameter for hook handle
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_hook_gethostname(void* replacement, PHookHandle* handle);

/**
 * Hook the getuid system call
 * @param replacement Replacement function pointer
 * @param handle Output parameter for hook handle
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_hook_getuid(void* replacement, PHookHandle* handle);

/**
 * Hook the getgid system call
 * @param replacement Replacement function pointer
 * @param handle Output parameter for hook handle
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_hook_getgid(void* replacement, PHookHandle* handle);

// Configuration-driven Hook Functions

/**
 * Configuration data for syscall hooks
 */
typedef struct {
    uid_t user_id;
    gid_t group_id;
    char hostname[256];
    char system_name[256];
    char machine[256];
    char release[256];
    char version[512];
} PHookConfigData;

/**
 * Install getuid hook with configured fake user ID
 * @param config_data Configuration data containing fake user ID
 * @param handle Output parameter for hook handle
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_install_getuid_hook(const PHookConfigData* config_data, PHookHandle* handle);

/**
 * Install getgid hook with configured fake group ID
 * @param config_data Configuration data containing fake group ID
 * @param handle Output parameter for hook handle
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_install_getgid_hook(const PHookConfigData* config_data, PHookHandle* handle);

/**
 * Install gethostname hook with configured fake hostname
 * @param config_data Configuration data containing fake hostname
 * @param handle Output parameter for hook handle
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_install_gethostname_hook(const PHookConfigData* config_data, PHookHandle* handle);

/**
 * Install uname hook with configured fake system information
 * @param config_data Configuration data containing fake system info
 * @param handle Output parameter for hook handle
 * @return PH_SUCCESS on success, error code on failure
 */
PHResult ph_install_uname_hook(const PHookConfigData* config_data, PHookHandle* handle);

// Utility Functions
/**
 * Get error message for a result code
 * @param result Result code
 * @return Human-readable error message
 */
const char* ph_get_error_message(PHResult result);

/**
 * Get version string
 * @return Version string in format "major.minor.patch"
 */
const char* ph_get_version(void);

/**
 * Check if the current platform is supported
 * @return true if supported, false otherwise
 */
bool ph_is_platform_supported(void);

// Debug and Logging Functions
/**
 * Set debug logging enabled/disabled
 * @param enabled true to enable debug logging
 */
void ph_set_debug_logging(bool enabled);

/**
 * Get the number of currently active hooks
 * @return Number of active hooks
 */
uint32_t ph_get_active_hook_count(void);

/**
 * Get list of all active hook function names
 * @param buffer Buffer to store function names (each null-terminated)
 * @param buffer_size Size of the buffer
 * @return Number of function names written to buffer
 */
uint32_t ph_get_active_hooks(char* buffer, size_t buffer_size);

#ifdef __cplusplus
}
#endif

#endif // PRIVARION_HOOK_H

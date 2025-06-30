#include "include/privarion_hook.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <dlfcn.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <pthread.h>

// Global state management
static bool g_hook_system_initialized = false;
static bool g_debug_logging_enabled = false;
static PHookEntry* g_hook_list_head = NULL;
static pthread_mutex_t g_hook_mutex = PTHREAD_MUTEX_INITIALIZER;
static uint32_t g_next_hook_id = 1;

// Global configuration data for hooks
static PHookConfigData g_config_data = {0};

// Internal helper functions
static void ph_log_debug(const char* format, ...);
static PHookEntry* ph_find_hook_by_name(const char* function_name);
static PHookEntry* ph_find_hook_by_id(uint32_t id);
static void ph_free_hook_entry(PHookEntry* entry);

// Pre-defined replacement functions

static uid_t hooked_getuid(void) {
    ph_log_debug("getuid() called, returning fake user ID: %d", g_config_data.user_id);
    return g_config_data.user_id;
}

static gid_t hooked_getgid(void) {
    ph_log_debug("getgid() called, returning fake group ID: %d", g_config_data.group_id);
    return g_config_data.group_id;
}

static int hooked_gethostname(char* name, size_t len) {
    ph_log_debug("gethostname() called, returning fake hostname: %s", g_config_data.hostname);
    size_t hostname_len = strlen(g_config_data.hostname);
    if (len <= hostname_len) {
        return -1; // ENAMETOOLONG
    }
    // Use strncpy with explicit null termination to prevent buffer overflow
    strncpy(name, g_config_data.hostname, len - 1);
    name[len - 1] = '\0';
    return 0;
}

static int hooked_uname(struct utsname* buf) {
    ph_log_debug("uname() called, returning fake system information");
    if (buf == NULL) {
        return -1;
    }
    
    strncpy(buf->sysname, g_config_data.system_name, sizeof(buf->sysname) - 1);
    strncpy(buf->machine, g_config_data.machine, sizeof(buf->machine) - 1);
    strncpy(buf->release, g_config_data.release, sizeof(buf->release) - 1);
    strncpy(buf->version, g_config_data.version, sizeof(buf->version) - 1);
    strncpy(buf->nodename, g_config_data.hostname, sizeof(buf->nodename) - 1);
    
    // Ensure null termination
    buf->sysname[sizeof(buf->sysname) - 1] = '\0';
    buf->machine[sizeof(buf->machine) - 1] = '\0';
    buf->release[sizeof(buf->release) - 1] = '\0';
    buf->version[sizeof(buf->version) - 1] = '\0';
    buf->nodename[sizeof(buf->nodename) - 1] = '\0';
    
    return 0;
}

// Configuration-driven hook installation functions

PHResult ph_install_getuid_hook(const PHookConfigData* config_data, PHookHandle* handle) {
    if (config_data == NULL || handle == NULL) {
        return PH_ERROR_INVALID_PARAM;
    }
    
    // Thread-safe update of global configuration
    pthread_mutex_lock(&g_hook_mutex);
    g_config_data.user_id = config_data->user_id;
    pthread_mutex_unlock(&g_hook_mutex);
    
    ph_log_debug("Installing getuid hook with fake user ID: %d", config_data->user_id);
    
    return ph_install_hook("getuid", (void*)hooked_getuid, handle);
}

PHResult ph_install_getgid_hook(const PHookConfigData* config_data, PHookHandle* handle) {
    if (config_data == NULL || handle == NULL) {
        return PH_ERROR_INVALID_PARAM;
    }
    
    // Thread-safe update of global configuration
    pthread_mutex_lock(&g_hook_mutex);
    g_config_data.group_id = config_data->group_id;
    pthread_mutex_unlock(&g_hook_mutex);
    
    ph_log_debug("Installing getgid hook with fake group ID: %d", config_data->group_id);
    
    return ph_install_hook("getgid", (void*)hooked_getgid, handle);
}

PHResult ph_install_gethostname_hook(const PHookConfigData* config_data, PHookHandle* handle) {
    if (config_data == NULL || handle == NULL) {
        return PH_ERROR_INVALID_PARAM;
    }
    
    // Update global configuration
    strncpy(g_config_data.hostname, config_data->hostname, sizeof(g_config_data.hostname) - 1);
    g_config_data.hostname[sizeof(g_config_data.hostname) - 1] = '\0';
    ph_log_debug("Installing gethostname hook with fake hostname: %s", config_data->hostname);
    
    return ph_install_hook("gethostname", (void*)hooked_gethostname, handle);
}

PHResult ph_install_uname_hook(const PHookConfigData* config_data, PHookHandle* handle) {
    if (config_data == NULL || handle == NULL) {
        return PH_ERROR_INVALID_PARAM;
    }
    
    // Update global configuration
    strncpy(g_config_data.system_name, config_data->system_name, sizeof(g_config_data.system_name) - 1);
    strncpy(g_config_data.machine, config_data->machine, sizeof(g_config_data.machine) - 1);
    strncpy(g_config_data.release, config_data->release, sizeof(g_config_data.release) - 1);
    strncpy(g_config_data.version, config_data->version, sizeof(g_config_data.version) - 1);
    strncpy(g_config_data.hostname, config_data->hostname, sizeof(g_config_data.hostname) - 1);
    
    // Ensure null termination
    g_config_data.system_name[sizeof(g_config_data.system_name) - 1] = '\0';
    g_config_data.machine[sizeof(g_config_data.machine) - 1] = '\0';
    g_config_data.release[sizeof(g_config_data.release) - 1] = '\0';
    g_config_data.version[sizeof(g_config_data.version) - 1] = '\0';
    g_config_data.hostname[sizeof(g_config_data.hostname) - 1] = '\0';
    
    ph_log_debug("Installing uname hook with fake system: %s", config_data->system_name);
    
    return ph_install_hook("uname", (void*)hooked_uname, handle);
}

// Core Implementation

PHResult ph_initialize(void) {
    pthread_mutex_lock(&g_hook_mutex);
    
    if (g_hook_system_initialized) {
        pthread_mutex_unlock(&g_hook_mutex);
        return PH_SUCCESS;
    }
    
    ph_log_debug("Initializing Privarion Hook System v%s", ph_get_version());
    
    // Check platform support
    if (!ph_is_platform_supported()) {
        pthread_mutex_unlock(&g_hook_mutex);
        return PH_ERROR_UNSUPPORTED_PLATFORM;
    }
    
    // Initialize hook list
    g_hook_list_head = NULL;
    g_next_hook_id = 1;
    g_hook_system_initialized = true;
    
    ph_log_debug("Hook system initialized successfully");
    pthread_mutex_unlock(&g_hook_mutex);
    return PH_SUCCESS;
}

void ph_cleanup(void) {
    pthread_mutex_lock(&g_hook_mutex);
    
    if (!g_hook_system_initialized) {
        pthread_mutex_unlock(&g_hook_mutex);
        return;
    }
    
    ph_log_debug("Cleaning up hook system");
    
    // Remove all hooks and free memory
    PHookEntry* current = g_hook_list_head;
    while (current != NULL) {
        PHookEntry* next = current->next;
        ph_free_hook_entry(current);
        current = next;
    }
    
    g_hook_list_head = NULL;
    g_hook_system_initialized = false;
    
    ph_log_debug("Hook system cleanup completed");
    pthread_mutex_unlock(&g_hook_mutex);
}

PHResult ph_install_hook(const char* function_name, 
                        void* replacement_function,
                        PHookHandle* handle) {
    if (!function_name || !replacement_function || !handle) {
        return PH_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&g_hook_mutex);
    
    if (!g_hook_system_initialized) {
        pthread_mutex_unlock(&g_hook_mutex);
        return PH_ERROR_INVALID_PARAM;
    }
    
    // Check if already hooked
    if (ph_find_hook_by_name(function_name) != NULL) {
        pthread_mutex_unlock(&g_hook_mutex);
        return PH_ERROR_ALREADY_HOOKED;
    }
    
    ph_log_debug("Installing hook for function: %s", function_name);
    
    // Get original function pointer
    void* original_function = dlsym(RTLD_DEFAULT, function_name);
    if (!original_function) {
        ph_log_debug("Function not found: %s", function_name);
        pthread_mutex_unlock(&g_hook_mutex);
        return PH_ERROR_FUNCTION_NOT_FOUND;
    }
    
    // Create new hook entry
    PHookEntry* new_hook = malloc(sizeof(PHookEntry));
    if (!new_hook) {
        pthread_mutex_unlock(&g_hook_mutex);
        return PH_ERROR_MEMORY_ERROR;
    }
    
    // Initialize hook entry
    strncpy(new_hook->function_name, function_name, sizeof(new_hook->function_name) - 1);
    new_hook->function_name[sizeof(new_hook->function_name) - 1] = '\0';
    new_hook->original_function = original_function;
    new_hook->replacement_function = replacement_function;
    new_hook->is_active = true;
    new_hook->next = g_hook_list_head;
    
    // Add to hook list
    g_hook_list_head = new_hook;
    
    // Setup handle
    handle->id = g_next_hook_id++;
    strncpy(handle->function_name, function_name, sizeof(handle->function_name) - 1);
    handle->function_name[sizeof(handle->function_name) - 1] = '\0';
    handle->is_valid = true;
    
    ph_log_debug("Hook installed successfully for function: %s (ID: %u)", function_name, handle->id);
    pthread_mutex_unlock(&g_hook_mutex);
    return PH_SUCCESS;
}

PHResult ph_remove_hook(const PHookHandle* handle) {
    if (!handle || !handle->is_valid) {
        return PH_ERROR_INVALID_PARAM;
    }
    
    pthread_mutex_lock(&g_hook_mutex);
    
    if (!g_hook_system_initialized) {
        pthread_mutex_unlock(&g_hook_mutex);
        return PH_ERROR_INVALID_PARAM;
    }
    
    ph_log_debug("Removing hook for function: %s (ID: %u)", handle->function_name, handle->id);
    
    // Find and remove hook from list
    PHookEntry* current = g_hook_list_head;
    PHookEntry* previous = NULL;
    
    while (current != NULL) {
        if (strcmp(current->function_name, handle->function_name) == 0) {
            // Remove from list
            if (previous) {
                previous->next = current->next;
            } else {
                g_hook_list_head = current->next;
            }
            
            ph_free_hook_entry(current);
            ph_log_debug("Hook removed successfully for function: %s", handle->function_name);
            pthread_mutex_unlock(&g_hook_mutex);
            return PH_SUCCESS;
        }
        
        previous = current;
        current = current->next;
    }
    
    pthread_mutex_unlock(&g_hook_mutex);
    return PH_ERROR_NOT_HOOKED;
}

void* ph_get_original(const PHookHandle* handle) {
    if (!handle || !handle->is_valid) {
        return NULL;
    }
    
    pthread_mutex_lock(&g_hook_mutex);
    
    PHookEntry* hook = ph_find_hook_by_name(handle->function_name);
    void* original = hook ? hook->original_function : NULL;
    
    pthread_mutex_unlock(&g_hook_mutex);
    return original;
}

bool ph_is_hooked(const char* function_name) {
    if (!function_name) {
        return false;
    }
    
    pthread_mutex_lock(&g_hook_mutex);
    bool hooked = (ph_find_hook_by_name(function_name) != NULL);
    pthread_mutex_unlock(&g_hook_mutex);
    
    return hooked;
}

// System Call Specific Implementations

PHResult ph_hook_uname(void* replacement, PHookHandle* handle) {
    return ph_install_hook("uname", replacement, handle);
}

PHResult ph_hook_gethostname(void* replacement, PHookHandle* handle) {
    return ph_install_hook("gethostname", replacement, handle);
}

PHResult ph_hook_getuid(void* replacement, PHookHandle* handle) {
    return ph_install_hook("getuid", replacement, handle);
}

PHResult ph_hook_getgid(void* replacement, PHookHandle* handle) {
    return ph_install_hook("getgid", replacement, handle);
}

// Utility Functions

const char* ph_get_error_message(PHResult result) {
    switch (result) {
        case PH_SUCCESS:
            return "Success";
        case PH_ERROR_INVALID_PARAM:
            return "Invalid parameter";
        case PH_ERROR_FUNCTION_NOT_FOUND:
            return "Function not found";
        case PH_ERROR_ALREADY_HOOKED:
            return "Function already hooked";
        case PH_ERROR_NOT_HOOKED:
            return "Function not hooked";
        case PH_ERROR_MEMORY_ERROR:
            return "Memory allocation error";
        case PH_ERROR_PERMISSION_DENIED:
            return "Permission denied";
        case PH_ERROR_UNSUPPORTED_PLATFORM:
            return "Unsupported platform";
        default:
            return "Unknown error";
    }
}

const char* ph_get_version(void) {
    static char version_string[32];
    snprintf(version_string, sizeof(version_string), "%d.%d.%d",
             PRIVARION_HOOK_VERSION_MAJOR,
             PRIVARION_HOOK_VERSION_MINOR,
             PRIVARION_HOOK_VERSION_PATCH);
    return version_string;
}

bool ph_is_platform_supported(void) {
#ifdef __APPLE__
    return true;
#else
    return false;
#endif
}

void ph_set_debug_logging(bool enabled) {
    g_debug_logging_enabled = enabled;
}

uint32_t ph_get_active_hook_count(void) {
    pthread_mutex_lock(&g_hook_mutex);
    
    uint32_t count = 0;
    PHookEntry* current = g_hook_list_head;
    while (current != NULL) {
        if (current->is_active) {
            count++;
        }
        current = current->next;
    }
    
    pthread_mutex_unlock(&g_hook_mutex);
    return count;
}

uint32_t ph_get_active_hooks(char* buffer, size_t buffer_size) {
    if (!buffer || buffer_size == 0) {
        return 0;
    }
    
    pthread_mutex_lock(&g_hook_mutex);
    
    uint32_t count = 0;
    size_t offset = 0;
    PHookEntry* current = g_hook_list_head;
    
    while (current != NULL && offset < buffer_size - 1) {
        if (current->is_active) {
            size_t name_len = strlen(current->function_name);
            if (offset + name_len + 1 < buffer_size) {
                strcpy(buffer + offset, current->function_name);
                offset += name_len + 1;
                count++;
            } else {
                break;
            }
        }
        current = current->next;
    }
    
    pthread_mutex_unlock(&g_hook_mutex);
    return count;
}

// Internal Helper Functions

static void ph_log_debug(const char* format, ...) {
    if (!g_debug_logging_enabled) {
        return;
    }
    
    va_list args;
    va_start(args, format);
    fprintf(stderr, "[PrivarionHook] ");
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");
    va_end(args);
}

static PHookEntry* ph_find_hook_by_name(const char* function_name) {
    PHookEntry* current = g_hook_list_head;
    while (current != NULL) {
        if (strcmp(current->function_name, function_name) == 0) {
            return current;
        }
        current = current->next;
    }
    return NULL;
}

static PHookEntry* ph_find_hook_by_id(uint32_t id) {
    // Note: This function could be enhanced to store ID in PHookEntry
    // For now, search by name is sufficient
    return NULL;
}

static void ph_free_hook_entry(PHookEntry* entry) {
    if (entry) {
        // Note: In a full implementation, would need to restore original function
        free(entry);
    }
}

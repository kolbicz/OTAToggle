#import "RootSpawn.h"
#import <spawn.h>
#import <sys/wait.h>
#import <unistd.h>
#import <dlfcn.h>
#import <sys/stat.h>

#define POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE 1
extern char **environ;

static NSString *ReadFD(int fd) {
    NSMutableData *data = NSMutableData.data;
    uint8_t buffer[1024]; ssize_t count;
    while ((count = read(fd, buffer, sizeof(buffer))) > 0) [data appendBytes:buffer length:(NSUInteger)count];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

int OTASpawnHelper(NSArray<NSString *> *arguments, NSString **output, NSString **errorOutput) {
    typedef int (*SetPersonaFn)(posix_spawnattr_t *, uid_t, uint32_t);
    typedef int (*SetPersonaUIDFn)(posix_spawnattr_t *, uid_t);
    typedef int (*SetPersonaGIDFn)(posix_spawnattr_t *, gid_t);
    SetPersonaFn setPersona=(SetPersonaFn)dlsym(RTLD_DEFAULT,"posix_spawnattr_set_persona_np");
    SetPersonaUIDFn setPersonaUID=(SetPersonaUIDFn)dlsym(RTLD_DEFAULT,"posix_spawnattr_set_persona_uid_np");
    SetPersonaGIDFn setPersonaGID=(SetPersonaGIDFn)dlsym(RTLD_DEFAULT,"posix_spawnattr_set_persona_gid_np");
    NSString *path = [NSBundle.mainBundle pathForResource:@"otatoggle-helper" ofType:nil];
    if (!path) { if (errorOutput) *errorOutput = @"Embedded helper is missing."; return 127; }
    NSMutableArray *all = [NSMutableArray arrayWithObject:path]; [all addObjectsFromArray:arguments];
    char **argv = calloc(all.count + 1, sizeof(char *));
    for (NSUInteger i = 0; i < all.count; i++) argv[i] = strdup([all[i] UTF8String]);
    int outPipe[2], errPipe[2]; pipe(outPipe); pipe(errPipe);
    posix_spawn_file_actions_t actions; posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_adddup2(&actions, outPipe[1], STDOUT_FILENO);
    posix_spawn_file_actions_adddup2(&actions, errPipe[1], STDERR_FILENO);
    posix_spawn_file_actions_addclose(&actions, outPipe[0]); posix_spawn_file_actions_addclose(&actions, errPipe[0]);
    posix_spawnattr_t attr; posix_spawnattr_init(&attr);
    struct stat helperStat={0}; BOOL isSetuid=(stat(path.fileSystemRepresentation,&helperStat)==0 && (helperStat.st_mode&S_ISUID));
    if(!isSetuid) {
        if(!setPersona || !setPersonaUID || !setPersonaGID) {
            close(outPipe[0]); close(outPipe[1]); close(errPipe[0]); close(errPipe[1]);
            for(NSUInteger i=0;i<all.count;i++) free(argv[i]); free(argv);
            posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attr);
            if(errorOutput) *errorOutput=@"The privileged helper is not installed correctly.";
            return 78;
        }
        setPersona(&attr,99,POSIX_SPAWN_PERSONA_FLAGS_OVERRIDE); setPersonaUID(&attr,0); setPersonaGID(&attr,0);
    }
    pid_t pid = 0; int result = posix_spawn(&pid, path.fileSystemRepresentation, &actions, &attr, argv, environ);
    close(outPipe[1]); close(errPipe[1]);
    NSString *out = ReadFD(outPipe[0]), *err = ReadFD(errPipe[0]); close(outPipe[0]); close(errPipe[0]);
    int status = 0; if (result == 0) waitpid(pid, &status, 0);
    for (NSUInteger i = 0; i < all.count; i++) free(argv[i]); free(argv);
    posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attr);
    if (output) *output = [out stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (errorOutput) *errorOutput = [err stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return result ?: (WIFEXITED(status) ? WEXITSTATUS(status) : 126);
}

#include <iostream>
#include <string>
#include <fstream>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <pwd.h>
#include <grp.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <libutil.h>

using namespace std;

string getFilename(string message) {
    size_t slash_pos = message.rfind("/")+1;
    size_t dquote_pos = message.find('"', slash_pos);
    string file = message.substr(slash_pos,dquote_pos-slash_pos);
    return file;
}

string getFilePath(string message) {
    size_t slash_pos = message.find("/");
    size_t dquote_pos = message.find('"', slash_pos);
    string file = message.substr(slash_pos,dquote_pos-slash_pos);
    return file;
}

string getAbsFilePath(string message) {
    string file = getFilePath(message);
    if (file[1]!='u') file.insert(0,"/usr/home/sftp");
    return file;
}

string getOwner(string filename) {
    string res;
    struct stat info;
    stat(filename.c_str(), &info);
    struct passwd *pw = getpwuid(info.st_uid);
    if (pw!=0) res += pw->pw_name;
    return res;
}

void moveFile(const char* from, const char* to) {
    std::ifstream  src(from, std::ios::binary);
    std::ofstream  dst(to,   std::ios::binary);
    dst << src.rdbuf();
    remove(from);
}

int main() {

    ifstream ifs("/var/log/sftp.log");
    ofstream ofs;
    int pid = (int) ::getpid();

    if (ifs.is_open()) {

        ifs.seekg(0,ifs.end);

        string line;
        
        while (true) {
            
            ofs.open("/var/log/sftp_watchd.log", ios::app);
            
            while (getline(ifs, line)) {
                
                string timestamp = line.substr(0,15);
                bool putting_file = line.find("CREATE")!=string::npos; 
                bool exe = line.find(".exe")!=string::npos; 

                if (putting_file && exe) {

                    string file = getAbsFilePath(line);
                    string owner = getOwner(file);
                    
                    char log[1000];
                    sprintf(log,"%s freebsd sftp_watchd[%d]: %s violate file detected. Uploaded by %s.\n", timestamp.c_str(), pid, file.c_str(), owner.c_str());
                    //ofs.open("/var/log/sftp_watchd.log", ios::app);
                    ofs << log;
                    //ofs.close();
                    
                    char newFilename[1000];
                    sprintf(newFilename,"/home/sftp/hidden/.exe/%s",getFilename(line).c_str());
                    moveFile(file.c_str(),newFilename);
                }
            }

            ofs.close();

            if (!ifs.eof()) break; 
            ifs.clear();

            usleep(10000);
        }
    }

    //pidfile_remove(pfh);

    return 0;
}

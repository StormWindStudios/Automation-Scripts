import paramiko
import time

USERNAME = "admin"                     #change
PASSWORD = ""                          #change
IP_FILE = "ips.txt"                    #change
LOG_FILE = "log_results.txt"           #change
COMMANDS = ["command 1", "command 2"]  #change

# Set up crappy legacy Cisco algorithms
paramiko.Transport._preferred_ciphers = ('aes128-cbc', )
paramiko.Transport._preferred_kex = ('diffie-hellman-group1-sha1', )

# Load IP addresses into a list
IP_LIST = []
with open(IP_FILE, "r") as ips:
    for ip in ips:
        IP_LIST.append(ip.strip())

def execute_commands(ip, log_file):
# Set up SSH client and connect to host
    sshclient = paramiko.SSHClient()
    sshclient.load_system_host_keys()
    sshclient.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    sshclient.connect(hostname=ip, port=22, username=USERNAME, password=PASSWORD)
    log_file.write("\n*************\n{}\n*************\n".format(ip))
    # While connected to host, execute each command in the command list
    # Save the stdout and stderror to the log file
    for command in COMMANDS:
        stdin, stdout, stderr = sshclient.exec_command(command)
        log_file.write(stdout.read().decode('ascii'))
        log_file.write(stderr.read().decode('ascii'))
        time.sleep(0.5)
    # Close session to device when done
    sshclient.close()


with open(LOG_FILE, "a") as log:
    print("Running commands:")
    for ip in IP_LIST:
        print("\t==> {}".format(ip))
        execute_commands(ip, log)

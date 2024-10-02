# Bootstrapping a K8 Cluster from Scratch

I recently started a new role as a Data Platform Engineer at Kraken, where we use Kubernetes on Amazon Elastic Kubernetes Service (EKS) for most of our data platform tooling (e.g. Airflow, dbt Core). To make sure my Kubernetes skills were up to scratch, I set out to bootstrap my own cluster using a set of EC2 instances by following this repo: [kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way/tree/master).

## Creating the virtual machines

The cluster is made up of four ARM64 virtual machines running Debian 12:
1. `jumpbox` (Administration host)
2. `server` (Kubernetes server)
3. `node-0` (Kubernetes worker node)
4. `node-1` (Kubernetes worker node)
 I created a Terraform workspace – [jack-white9/k8-cluster-bootstrap/terraform](https://github.com/jack-white9/k8-cluster-bootstrap/tree/main/terraform) – to provision the VMs as EC2 instances, along with a VPC and security group (with an ingress SSH rule). To deploy the resources, I simply applied my Terraform configuration while authenticated to my AWS account.
```bash
terraform apply
```

![list of ec2 instances](./images/instances.png)

## Setting up the Jumpbox

One of the VMs has been set up as a jumpbox, which will be used as the home base to run commands that interact with the cluster. To set up the jumpbox, I connected to the `jumpbox` instance.
```bash
ssh -i k8-jumpbox-key-pair.pem admin@<public-ipv4-address>
```

From there, I went through the following actions to install some required tooling:
1. Installing basic packages (`wget`, `curl`, `vim`, `openssl`, `git`)
```bash
sudo apt-get update &&\
sudo apt-get -y install wget curl vim openssl git
```
2. Cloning the utilities repo (includes binaries and services)
```bash
git clone --depth 1 \
https://github.com/kelseyhightower/kubernetes-the-hard-way.git && \
cd kubernetes-the-hard-way
```
3. Downloading Kubernetes binaries (including `kubectl`, `kube-apiserver`, `kube-controller-manager`, and others)
```bash
wget -q --show-progress \
  --https-only \
  --timestamping \
  -P downloads \
  -i downloads.txt
```
4. Adding the `kubectl` binary to `/usr/local/bin`
```bash
chmod +x downloads/kubectl && cp downloads/kubectl /usr/local/bin/
```

Finally, I verified the `kubectl` installation before moving on.
```bash
kubectl version --client
```

```
Client Version: v1.28.3
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
```

## Configuring Compute Resources

### Creating a "database"

To get started, I created a simple "database" containing the `IPV4_ADDRESS`, `FQDN`, `HOSTNAME`, and `POD_SUBNET` of each machine. I created `machines.txt` with the following information *(IP addresses have been masked here for security purposes)*:
```
XXX.XXX.XXX.XXX server.kubernetes.local server  
XXX.XXX.XXX.XXX node-0.kubernetes.local node-0 10.200.0.0/24
XXX.XXX.XXX.XXX node-1.kubernetes.local node-1 10.200.1.0/24
```

### Enabling SSH access

Firstly, I enabled root access to `server`, `node-0`, and `node-1` *(not best practice, but will make life a little easier for the sake of this exercise)* by running the following command inside each instance:
```bash
sed -i \
  's/^#PermitRootLogin.*/PermitRootLogin yes/' \
  /etc/ssh/sshd_config
```

Next, I went ahead and generated an SSH key in `jumpbox` that will be used to connect to each machine.
```bash
ssh-keygen
```

Once the SSH key was generated, I copied the contents of the public key (`~/.ssh/id_rsa.pub`) and appended it to `~/.ssh/authorized_keys` in each machine (`server`, `node-0`, and `node-1`).

Finally, to confirm that SSH access from `jumpbox` to each machine was working, I ran the following command:
```bash
while read IP FQDN HOST SUBNET; do 
  ssh -n root@${IP} uname -o -m
done < machines.txt
```

```
aarch64 GNU/Linux
aarch64 GNU/Linux
aarch64 GNU/Linux
```

### Configuring hostnames

Hostnames make communication within the cluster more manageable by providing human-readable names instead of IP addresses. To add hostnames to each of the machines, I ran the following command from `jumpbox`, which appends each respective hostname to `/etc/hosts` and adds the hostname to `hostnamectl`.
```bash
while read IP FQDN HOST SUBNET; do
    CMD="echo '127.0.1.1	${FQDN} ${HOST}' >> /etc/hosts"
    ssh -n root@${IP} "$CMD"
    ssh -n root@${IP} hostnamectl hostname ${HOST}
done < machines.txt
```

Once added, I verified the hostnames had been set correctly.
```bash
while read IP FQDN HOST SUBNET; do
  ssh -n root@${IP} hostname --fqdn
done < machines.txt
```

```
server.kubernetes.local
node-0.kubernetes.local
node-1.kubernetes.local
```

### Configuring DNS

For the final step of configuring the compute resources, I mapped each hostname to their respective IPv4 address in `/etc/hosts` to allow each machine to be reachable using their hostname (`server`, `node-0`, or `node-1`).

To do this, I started by creating a temporary DNS `hosts` file.
```bash
while read IP FQDN HOST SUBNET; do
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo $ENTRY >> hosts
done < machines.txt
```

 Once the `hosts` file was created and populated, I appended the content of `hosts` to each machine (including `jumpbox`).
```bash
# jumpbox
cat hosts >> /etc/hosts

# remote machines (server, node-0, node-1)
while read IP FQDN HOST SUBNET; do
  scp hosts root@${HOST}:~/
  ssh -n \
    root@${HOST} "cat hosts >> /etc/hosts"
done < machines.txt
```

Finally, to confirm that DNS had been configured correctly, I connected to the machines using their hostnames instead of IP addresses.

```bash
while read IP FQDN HOST SUBNET; do
	ssh -n root@${HOST} uname -o -n -m
done < machines.txt
```

```
server aarch64 GNU/Linux
node-0 aarch64 GNU/Linux
node-1 aarch64 GNU/Linux
```

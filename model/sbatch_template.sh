#!/bin/bash
#SBATCH --partition={{PARTITION_NAME}}
#SBATCH --job-name={{JOB_NAME}}
#SBATCH --output={{JOB_NAME}}.log
{{GIVEN_NODE}}

### This script works for any number of nodes, Ray will find and manage all resources
#SBATCH --nodes={{NUM_NODES}}
#SBATCH --exclusive

### Give all resources to a single Ray task, ray can manage the resources internally
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-task={{NUM_GPUS_PER_NODE}}
#SBATCH --cpus-per-task={{NUM_CPUS_PER_NODE}}
#SBATCH --time={{MAX_TIME}}
#SBATCH --mem=20G
#SBATCH --mail-user=wenbinxu@fhi-berlin.mpg.de
#SBATCH --mail-type=END

### COSTUM setting
# Load modules or your own conda environment here
# module load pytorch/v1.4.0-gpu
# conda activate {{CONDA_ENV}}
{{LOAD_ENV}}

# This script is a modification to the implementation suggest by gregSchwartz18 here:
redis_password=$(uuidgen)
export redis_password

nodes=$(scontrol show hostnames $SLURM_JOB_NODELIST) # Getting the node names
nodes_array=($nodes)

node_1=${nodes_array[0]}
ip=$(srun --nodes=1 --ntasks=1 -w $node_1 hostname --ip-address) # making redis-address

if [[ $ip == *" "* ]]; then
  IFS=' ' read -ra ADDR <<<"$ip"
  if [[ ${#ADDR[0]} > 16 ]]; then
    ip=${ADDR[1]}
  else
    ip=${ADDR[0]}
  fi
  echo "We detect space in ip! You are using IPV6 address. We split the IPV4 address as $ip"
fi

port=6379
ip_head=$ip:$port
export ip_head
echo "IP Head: $ip_head"

echo "STARTING HEAD at $node_1"
# srun --nodes=1 --ntasks=1 -w $node_1 start-head.sh $ip $redis_password &
srun --nodes=1 --ntasks=1 -w $node_1 \
  ray start --head --node-ip-address=$ip --port=6379 --redis-password=$redis_password --block &
sleep 30

worker_num=$(($SLURM_JOB_NUM_NODES - 1)) #number of nodes other than the head node
for ((i = 1; i <= $worker_num; i++)); do
  node_i=${nodes_array[$i]}
  echo "STARTING WORKER $i at $node_i"
  srun --nodes=1 --ntasks=1 -w $node_i ray start --address $ip_head --redis-password=$redis_password --block &
  sleep 5
done

##############################################################################################

#### call your code below
{{COMMAND_PLACEHOLDER}} {{COMMAND_SUFFIX}}

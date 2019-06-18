# 先登陆服务器，切换到root用户再操作

# ########################## 配置项 ##########################

# 部署相关
dir_parent=$(cd `dirname $0`;pwd)
conf_supervisor=$dir_parent/mlflow.ini
dir_deploy=/data
dir_supervisor_config=/etc/supervisor/config.d

# 环境相关
env_name=mlflow
dir_bin=$(conda info --base)/envs/$env_name/bin
pip=$dir_bin/pip
mlflow=$dir_bin/mlflow
python=$dir_bin/python

# ########################## 关闭服务 ##########################

supervisorctl stop mlflow
for pid in $(pidof -x mlflow); do
    if [ $pid != $$ ]; then
        echo "[$(date)] : devpi : 程序正在运行， PID $pid"
        kill -9 $pid
    fi
done
echo "服务全关闭"

# ########################## 安装并配置 ##########################

# 创建并激活虚拟环境，再在虚拟环境里安装mlflow
conda create -n $env_name python=3.6 -y
$pip install scipy==1.2.1 -i https://pypi.tuna.tsinghua.edu.cn/simple
$pip install mlflow -i https://pypi.tuna.tsinghua.edu.cn/simple

# 更新supervisor配置文件
if [ -d "$dir_supervisor_config" ]
then
    /bin/cp -rf $conf_supervisor $dir_supervisor_config
    echo "supervisor配置完成"
else
    echo "请安装supervisor来持久化服务：https://github.com/uncleguanghui/centos-supervisor"
fi

# 克隆到/data目录下
cd $dir_deploy
git clone https://github.com/mlflow/mlflow.git
cd mlflow/examples

# 生成启动脚本
content="cd $(pwd)\n ln -fs $dir_bin/gunicorn /bin/gunicorn \n $mlflow server --backend-store-uri ./mlruns --default-artifact-root ./mlruns --host 0.0.0.0 --port 8014"
echo "$content" > run_mlflow.sh

# 一开始是没有任何结果的，需要先跑一个
$python sklearn_elasticnet_wine/train.py 0 0

# 启动后端服务
if [ -d "$dir_supervisor_config" ]
then
    supervisorctl update
else
    sh run_mlflow.sh
fi

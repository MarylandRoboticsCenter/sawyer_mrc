##############
# modified full ubuntu image #
##############
FROM osrf/ros:noetic-desktop AS noetic-mod_desktop

# Set default shell
SHELL ["/bin/bash", "-c"]

WORKDIR ${HOME}

ENV DEBIAN_FRONTEND=noninteractive

# Basic setup
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends --allow-unauthenticated \
    build-essential \
    curl \
    g++ \
    git \
    ca-certificates \
    make \
    cmake \
    automake \
    autoconf \
    bash-completion \
    iproute2 \
    iputils-ping \
    pkg-config \
    libxext-dev \
    libx11-dev \
    mc \
    mesa-utils \
    nano \
    software-properties-common \
    sudo \
    tmux \
    tzdata \
    xclip \
    x11proto-gl-dev && \
    sudo rm -rf /var/lib/apt/lists/*

# Set datetime and timezone correctly
RUN sudo ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo '$TZ' | sudo tee -a /etc/timezone

ENV DEBIAN_FRONTEND=dialog


##############
# Aux ROS2 packages #
##############
FROM noetic-mod_desktop AS noetic-dev

# Install ROS packages
RUN sudo apt-get update && sudo apt-get install -y \
    ros-noetic-xacro \
    python-is-python3 \
    python3-catkin-tools \
    python3-pip && \
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*


##############
# user with matching uid and gid#
##############
FROM noetic-dev AS noetic-user

ARG WS_DIR="dir_ws"
ARG USERNAME=user
ARG userid=1111
ARG groupid=1111
ARG PW=user@123
ARG ROBOT_IP=127.0.0.1

RUN groupadd -g ${groupid} -o ${USERNAME}
RUN useradd --system --create-home --home-dir /home/${USERNAME} --shell /bin/bash --uid ${userid} -g ${groupid} --groups sudo,video ${USERNAME} && \
    echo "${USERNAME}:${PW}" | chpasswd && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

ENV USER=${USERNAME} \
    LANG=en_US.UTF-8 \
    HOME=/home/${USERNAME} \
    XDG_RUNTIME_DIR=/run/user/${userid} \
    TZ=America/New_York

USER ${USERNAME}
WORKDIR ${HOME}

# custom Bash prompt
RUN { echo && echo "PS1='\[\e]0;\u \w\a\]\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\] \\\$ '" ; } >> .bashrc

RUN sudo mkdir -p -m 0700 /run/user/${userid} && \
    sudo chown ${USERNAME}:${USERNAME} /run/user/${userid}

# Setup tmux config
ADD --chown=${USERNAME}:${USERNAME} https://raw.githubusercontent.com/MarylandRoboticsCenter/someConfigs/refs/heads/master/.tmux_K.conf $HOME/.tmux.conf


#####################
# ROS workspace #
#####################
FROM noetic-user AS noetic-user_ws

WORKDIR ${HOME}

# Create workspace folder
RUN source /opt/ros/noetic/setup.bash && \
    mkdir -p $HOME/${WS_DIR}/src && \
    cd $HOME/${WS_DIR} && \
    catkin build

RUN echo 'source /opt/ros/noetic/setup.bash' >> $HOME/.bashrc && \
    echo >> $HOME/.bashrc && \
    echo "source $HOME/${WS_DIR}/devel/setup.bash" >> $HOME/.bashrc


#####################
# Sawyer ROS packages#
#####################
FROM noetic-user_ws AS noetic-sawyer_mrc

# installing additional Sawyer packages
RUN sudo apt-get update && sudo apt-get install -y \
    ros-noetic-moveit-visual-tools \
    ros-noetic-moveit \
    ros-noetic-usb-cam \
    ros-noetic-control-msgs \
    ros-noetic-xacro \
    ros-noetic-tf2-ros \
    ros-noetic-rviz \
    ros-noetic-cv-bridge \
    ros-noetic-actionlib \
    ros-noetic-actionlib-msgs \
    ros-noetic-dynamic-reconfigure \
    ros-noetic-trajectory-msgs \
    ros-noetic-rospy-message-converter  && \
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*

RUN pip install argparse

# Create driver workspace folder
RUN source /opt/ros/noetic/setup.bash && \
    mkdir -p $HOME/ros_sawyer_driver/src && \
    cd $HOME/ros_sawyer_driver/src && \
    wstool init . && \
    git clone https://github.com/RethinkRobotics/sawyer_robot.git && \
    wstool merge sawyer_robot/sawyer_robot.rosinstall && \
    wstool update && \
    wstool merge https://raw.githubusercontent.com/RethinkRobotics/sawyer_moveit/melodic_devel/sawyer_moveit.rosinstall && \
    wstool update && \
    cd $HOME/ros_sawyer_driver && \
    catkin build

RUN cd $HOME/ros_sawyer_driver && \
    cp ./src/intera_sdk/intera.sh .

# # installing Sawyer Gazebo packages
# RUN sudo apt-get update && sudo apt-get install -y \
#     gazebo11 \
#     ros-noetic-gazebo-ros \
#     ros-noetic-gazebo-ros-control \
#     ros-noetic-gazebo-ros-pkgs \
#     ros-noetic-ros-control \
#     ros-noetic-control-toolbox \
#     ros-noetic-realtime-tools \
#     ros-noetic-ros-controllers \
#     ros-noetic-xacro \
#     python3-wstool \
#     ros-noetic-tf-conversions \
#     ros-noetic-kdl-parser && \
#     sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*

#     RUN source /opt/ros/noetic/setup.bash && \
#     mkdir -p $HOME/ros_sawyer_sim/src && \
#     cd $HOME/ros_sawyer_sim/src && \
#     git clone https://github.com/RethinkRobotics/sawyer_simulator.git -b noetic_devel && \
#     git clone https://github.com/RethinkRobotics-opensource/sns_ik.git -b melodic-devel && \
#     wstool init . && \
#     wstool merge sawyer_simulator/sawyer_simulator.rosinstall && \
#     wstool update && \
#     cd $HOME/ros_sawyer_sim 
#     && \
#     catkin build    

RUN echo >> $HOME/.bashrc && \
    echo "source $HOME/ros_sawyer_driver/devel/setup.bash" >> $HOME/.bashrc
    # echo "source $HOME/ros_sawyer_sim/devel/setup.bash" >> $HOME/.bashrc

CMD /bin/bash
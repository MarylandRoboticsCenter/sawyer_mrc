Docker image for working with Sawyer. The image is based on Ubuntu 20.04.

* Build ROS Noetic docker image (run the command from the `docker` folder):
    ```
    userid=$(id -u) groupid=$(id -g) docker compose -f noetic-sawyer_mrc-compose.yml build
    ```    
* Start the container:
    ```
    docker compose -f noetic-sawyer_mrc-compose.yml run --rm noetic-sawyer_mrc-docker
    ```

Gazebo simulation has some issues due to OpenCV changes in the newer version. The new function `imread` should be `cv::IMREAD_UNCHANGED`.


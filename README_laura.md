# IotProject - LoraWAN Network

<p align="center">
Noemi Manzo
<p align="center">
Laura Pozzi



This repository contains the solution to project number 2 of the Politecnico di Milano course Internet of things class 2023. 

## Description 

The aim of this project is to implement and showcase a network architecture similar to LoraWAN within the TinyOS environment with the following topology:

<p align="center">
  <img src="Images/network.png" />
</p>

Sensor nodes 1,2,3,4,5 periodically transmit random data that are received by one or more gateways. These two forward the messages to the network server. The server saves the data received and send back an ack packet. If the ack is not received by the sensor within 1s, the message is re-transmitted.  

## Implementation

The project was executed in several steps, each focusing on different aspects of the implementation. The key platforms used throughout the project are:

1. `TinyOS` with TOSSIM simulator for logical implementation: in this phase we were able to logically implement the essential components, including node, communication, ack and duplicated messages management.
2. `Node-RED` for MQTT transmission: we integrate Node-RED to establish a MQTT-based connection between the simulated Network Server and an external environment to send sensor nodes data.
3. `Thingspeak` for graphical visualization of sensor data: it enables the real-time display of collected information sent by Node-RED on a public channel


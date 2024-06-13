#!/bin/bash

#PBS -q tqueue
#PBS -N ALL_JRA3Q_HGT
#PBS -j oe
#PBS -l nodes=1:ppn=1

cd /mnt/hail8/kosei/JRA3Q/ALL/

bash convert_hgt.sh


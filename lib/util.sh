#!/bin/bash

function vdc_origin_url(){
  (cd ${vdc_dir} && git config --get remote.origin.url)
}

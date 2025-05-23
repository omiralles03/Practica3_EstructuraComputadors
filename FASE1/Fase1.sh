#!/bin/bash

# Obtener el directorio del script
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ruta al simulador
SIMULATOR="sim-outorder"

# Parámetros comunes
FASTFWD=100000000
MAX_INST=100000000

# Obtener el tiempo de inicio
start_time=$(date +%s)

# Tarea seleccionada (por defecto es 0, que ejecuta todas)
TAREA=${1:-0}

# Benchmarks y sus comandos específicos
declare -A BENCHMARKS
BENCHMARKS["applu"]="< applu.in > applu.out 2> applu.err"
BENCHMARKS["art"]="-scanfile c756hel.in -trainfile1 a10.img -trainfile2 hc.img -stride 2 -startx 110 -starty 200 -endx 160 -endy 240 -objects 10 > ref.1.out 2> ref.1.err"
BENCHMARKS["gzip"]="input.log 60 > input.log.out 2> input.log.err"
BENCHMARKS["mesa"]="-frames 1000 -meshfile mesa.in -ppmfile mesa.ppm"
BENCHMARKS["twolf"]="ref > ref.stdout 2> ref.err"

# Configuración base de cachés
BASE_CACHES=("dl1" "il1" "ul2")
BASE_SIZES=(8 16 64)
BASE_ASSOCS=(4 2 8)
BASE_BLOCK_SIZES=(32 32 64)
REPLACEMENT="l"

function show_time() {
  # Obtener el tiempo de finalización
  end_time=$(date +%s)

  # Calcular la diferencia de tiempo
  execution_time=$((end_time - start_time))

  # Convertir el tiempo a minutos y segundos
  minutes=$((execution_time / 60))
  seconds=$((execution_time % 60))

  # Imprimir el tiempo de ejecución en formato min:seg
  echo -e "\nTiempo total de ejecución: $minutes min $seconds seg\n"
}

# Función para ejecutar una simulación
execute_simulation() {
  local BENCH=$1
  local CACHE_TYPE=$2
  local SIZE=$3
  local ASSOC=$4
  local BLOCK_SIZE=$5
  local TASK_NUM=$6
  echo "BSIZE: $BLOCK_SIZE, ASSOC: $ASSOC)"

  if [ "$ASSOC" -gt 128 ]; then
  	local NSETS=1
  else
  	local NSETS=$((SIZE * 1024 / (BLOCK_SIZE * ASSOC)))
  fi
  	
  local OUTPUT_DIR="$BASE_DIR/T$TASK_NUM/$BENCH/Result_${BENCH}_${CACHE_TYPE}_${SIZE}KB.txt"
  local EXE="$BASE_DIR/../$BENCH/exe/$BENCH.exe"
  local COMMAND="${BENCHMARKS[$BENCH]}"

  local OUTPUT_DIR_PATH="$(dirname "$OUTPUT_DIR")"
  mkdir -p "$OUTPUT_DIR_PATH"

  # Cambiar al directorio deseado
  cd "$BASE_DIR/../$BENCH/data/ref" || return

  if [[ "$CACHE_TYPE" == "ul2" ]]; then
    local SIM_COMMAND="$SIMULATOR -fastfwd $FASTFWD -max:inst $MAX_INST -cache:dl2 ul2:${NSETS}:${BLOCK_SIZE}:${ASSOC}:${REPLACEMENT} -redir:sim $OUTPUT_DIR $EXE $COMMAND"
  else
    local SIM_COMMAND="$SIMULATOR -fastfwd $FASTFWD -max:inst $MAX_INST -cache:${CACHE_TYPE} ${CACHE_TYPE}:${NSETS}:${BLOCK_SIZE}:${ASSOC}:${REPLACEMENT} -redir:sim $OUTPUT_DIR $EXE $COMMAND"
  fi

  echo "Executing ($BENCH, $CACHE_TYPE, $SIZE): $SIM_COMMAND"
  eval $SIM_COMMAND

  local OUTPUT_FILE="$BASE_DIR/T$TASK_NUM/$BENCH/Estudi_${BENCH}.txt"
  # Realizar grep para sim_IPC y miss_rate y agregar al archivo de salida
  grep "sim_IPC\|$CACHE_TYPE.miss_rate" "$OUTPUT_DIR" >>"$BASE_DIR/T$TASK_NUM/$BENCH/Estudi_${BENCH}.txt"

  show_time
}

# Ejecutar simulaciones basadas en la tarea seleccionada
for BENCH in "${!BENCHMARKS[@]}"; do

    for i in "${!BASE_CACHES[@]}"; do
      if [[ $TAREA -eq 0 || $TAREA -eq 1 ]]; then
		  CACHE_TYPE="${BASE_CACHES[$i]}"
		  SIZE="${BASE_SIZES[$i]}"
		  ASSOC="${BASE_ASSOCS[$i]}"
		  BLOCK_SIZE="${BASE_BLOCK_SIZES[$i]}"
		  execute_simulation "$BENCH" "$CACHE_TYPE" "$SIZE" "$ASSOC" "$BLOCK_SIZE" 1
      fi
    done

  if [[ $TAREA -eq 0 || $TAREA -eq 2 ]]; then
    CACHE_TYPE="dl1"
    ASSOC=4
    BLOCK_SIZE=32
    for SIZE in 1 2 4 8 16 32 64; do
      execute_simulation "$BENCH" "$CACHE_TYPE" "$SIZE" "$ASSOC" "$BLOCK_SIZE" 2
    done
  fi

  if [[ $TAREA -eq 0 || $TAREA -eq 3 ]]; then
    CACHE_TYPE="il1"
    ASSOC=2
    BLOCK_SIZE=32
    for SIZE in 1 2 4 8 16 32 64; do
      execute_simulation "$BENCH" "$CACHE_TYPE" "$SIZE" "$ASSOC" "$BLOCK_SIZE" 3
    done
  fi

  if [[ $TAREA -eq 0 || $TAREA -eq 4 ]]; then
    CACHE_TYPE="ul2"
    ASSOC=8
    BLOCK_SIZE=64
    for SIZE in 32 64 128 256 512; do
      execute_simulation "$BENCH" "$CACHE_TYPE" "$SIZE" "$ASSOC" "$BLOCK_SIZE" 4
    done
  fi

  if [[ $TAREA -eq 0 || $TAREA -eq 5 ]]; then
    CACHE_TYPE="dl1"
    SIZE=8
    BLOCK_SIZE=32
	# Totalmente asoc -> nsets = 1, assoc = 8096 / 32 = 256
    for ASSOC in 1 2 4 8 16 32 64 256; do
      execute_simulation "$BENCH" "$CACHE_TYPE" "$SIZE" "$ASSOC" "$BLOCK_SIZE" 5
    done
  fi

  if [[ $TAREA -eq 0 || $TAREA -eq 6 ]]; then
    CACHE_TYPE="il1"
    SIZE=16
    BLOCK_SIZE=32
	# Totalmente asoc -> nsets = 1, assoc = 16384 / 32 = 512
    for ASSOC in 1 2 4 8 16 32 64 512; do
      execute_simulation "$BENCH" "$CACHE_TYPE" "$SIZE" "$ASSOC" "$BLOCK_SIZE" 6
    done
  fi

  if [[ $TAREA -eq 0 || $TAREA -eq 7 ]]; then
    CACHE_TYPE="dl1"
    SIZE=8
    ASSOC=4
    for BLOCK_SIZE in 8 16 32 64; do
      execute_simulation "$BENCH" "$CACHE_TYPE" "$SIZE" "$ASSOC" "$BLOCK_SIZE" 7
    done
  fi

  if [[ $TAREA -eq 0 || $TAREA -eq 8 ]]; then
    CACHE_TYPE="il1"
    SIZE=16
    ASSOC=2
    for BLOCK_SIZE in 8 16 32 64; do
      execute_simulation "$BENCH" "$CACHE_TYPE" "$SIZE" "$ASSOC" "$BLOCK_SIZE" 8
    done
  fi
done

show_time

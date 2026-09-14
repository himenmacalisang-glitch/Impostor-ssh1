#!/bin/bash
# ==============================================================================
# IMPOSTOR SSH GATEWAY DEPLOYER (CLOUD RUN EDITION)
# ==============================================================================

BOLD='\033[1m'; RESET='\033[0m'; NC='\033[0m'
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'
YELLOW='\033[1;33m'; MAGENTA='\033[1;35m'; WHITE='\033[1;37m'

loading() {
    local t="$1"
    local s="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    for ((i=0;i<5;i++)); do
        for ((j=0;j<${#s};j++)); do
            echo -ne "\r  ${CYAN}${s:$j:1} ${t}...${RESET}"
            sleep 0.05
        done
    done
    echo -ne "\r  ${GREEN}DONE: ${t}${RESET}\n"
}

clear
echo ""
echo -e "  ${BOLD}${GREEN}IMPOSTOR SSH GATEWAY DEPLOYER${RESET}"
echo -e "  ${CYAN}Powered by IMPOSTOR GCP${RESET}"
echo ""

PROJECT_ID=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')
if [ -z "$PROJECT_ID" ]; then
    echo -e "  ${RED}ERROR: No active GCP project detected. Run 'gcloud init' first.${RESET}"
    exit 1
fi
echo -e "  ${CYAN}PROJECT: ${GREEN}${PROJECT_ID}${RESET}"
echo ""

echo -e "  ${CYAN}==================================================${NC}"
echo -e "  ${GREEN}                 SERVICE NAME${NC}"
echo -e "  ${CYAN}==================================================${NC}"
read -r -p "$(echo -e "  ${CYAN}SERVICE NAME [impostor]: ${RESET}")" INPUT_NAME
SERVICE_NAME=${INPUT_NAME:-impostor}
echo ""

echo -e "  ${CYAN}==================================================${NC}"
echo -e "  ${GREEN}              SELECT DEPLOY REGION${NC}"
echo -e "  ${CYAN}==================================================${NC}"
echo -e "  ${YELLOW}1) asia-southeast1  (Singapore - SEA)${RESET}"
echo -e "  ${YELLOW}2) asia-east1       (Taiwan)${RESET}"
echo -e "  ${YELLOW}3) us-central1      (Iowa - USA)${RESET}"
echo -e "  ${YELLOW}4) us-west1         (Oregon)${RESET}"
echo ""
read -r -p "$(echo -e "  ${CYAN}REGION [1-4]: ${RESET}")" REGION_CHOICE
case "$REGION_CHOICE" in
    1) REGION="asia-southeast1" ;;
    2) REGION="asia-east1" ;;
    3) REGION="us-central1" ;;
    4) REGION="us-west1" ;;
    *) REGION="us-central1" ;;
esac
echo -e "  ${GREEN}SELECTED REGION: ${REGION}${RESET}"
echo ""

echo -e "  ${CYAN}==================================================${NC}"
echo -e "  ${GREEN}                  SELECT MODE${NC}"
echo -e "  ${CYAN}==================================================${NC}"
echo -e "  ${YELLOW}1) BROWSING     (1 vCPU / 2Gi   RAM)${RESET}"
echo -e "  ${YELLOW}2) STREAMING    (2 vCPU / 4Gi   RAM)${RESET}"
echo -e "  ${YELLOW}3) GAMING       (4 vCPU / 8Gi   RAM)${RESET}"
echo -e "  ${YELLOW}4) ULTRA        (4 vCPU / 16Gi  RAM)${RESET}"
echo -e "  ${YELLOW}5) CUSTOM${RESET}"
echo ""
read -r -p "$(echo -e "  ${CYAN}CHOICE [1-5]: ${RESET}")" MODE_CHOICE
case "$MODE_CHOICE" in
    2) CPU="2"; RAM="4Gi"; MODE="STREAMING"; MAX_INSTANCES="4";;
    3) CPU="4"; RAM="8Gi"; MODE="GAMING"; MAX_INSTANCES="4";;
    4) CPU="4"; RAM="16Gi"; MODE="ULTRA"; MAX_INSTANCES="4";;
    5)
        echo ""
        read -r -p "$(echo -e "  ${CYAN}CPU (1/2/4/8): ${RESET}")" CPU
        read -r -p "$(echo -e "  ${CYAN}RAM (2Gi/4Gi/8Gi/16Gi): ${RESET}")" RAM
        read -r -p "$(echo -e "  ${CYAN}MAX INSTANCES (1-8): ${RESET}")" MAX_INSTANCES
        MODE="CUSTOM"
        ;;
    *) CPU="1"; RAM="2Gi"; MODE="BROWSING"; MAX_INSTANCES="2";;
esac
echo -e "  ${GREEN}SELECTED MODE: ${MODE} (${CPU} vCPU / ${RAM})${RESET}"
echo ""

loading "BUILDING IMAGE"
gcloud builds submit --tag "gcr.io/${PROJECT_ID}/${SERVICE_NAME}" --project="$PROJECT_ID" --quiet > build.log 2>&1
if [ $? -ne 0 ]; then
    echo -e "  ${RED}BUILD FAILED:${RESET}"
    tail -n 10 build.log
    exit 1
fi

deploy_attempt() {
    local cpu="$1" mem="$2" maxi="$3" extra_flags="$4"
    gcloud run deploy "$SERVICE_NAME" \
        --image "gcr.io/${PROJECT_ID}/${SERVICE_NAME}" \
        --platform managed --region "$REGION" \
        --port 8080 --allow-unauthenticated --project="$PROJECT_ID" \
        --cpu "$cpu" --memory "$mem" --max-instances "$maxi" \
        --timeout 3600 --quiet $extra_flags > deploy.log 2>&1
}

loading "DEPLOYING TO CLOUD RUN — ${REGION}"
if deploy_attempt "$CPU" "$RAM" "$MAX_INSTANCES" "--no-cpu-throttling --cpu-boost --session-affinity --execution-environment gen2 --min-instances 1 --concurrency 250"; then
    FINAL_CPU="$CPU"; FINAL_RAM="$RAM"; FINAL_NOTE="full performance mode"
elif deploy_attempt 1 512Mi 2 "--no-cpu-throttling --session-affinity --min-instances 1 --concurrency 150"; then
    FINAL_CPU="1"; FINAL_RAM="512Mi"; FINAL_NOTE="reduced tier — quota limit"
elif deploy_attempt 1 512Mi 2 "--min-instances 0 --concurrency 100"; then
    FINAL_CPU="1"; FINAL_RAM="512Mi"; FINAL_NOTE="minimal tier — cold start possible"
else
    echo -e "  ${RED}ALL DEPLOY ATTEMPTS FAILED${RESET}"
    tail -n 10 deploy.log
    exit 1
fi

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --project="$PROJECT_ID" --format='value(status.url)' 2>/dev/null)
CLEAN_HOST=$(echo "$SERVICE_URL" | sed 's|https://||')

echo ""
echo -e "  ${GREEN} ✅ DEPLOYED SUCCESSFULLY${RESET}"
echo ""
echo -e "  ${CYAN}SERVICE      ${GREEN}${SERVICE_NAME}${RESET}"
echo -e "  ${CYAN}HOST         ${GREEN}${CLEAN_HOST}${RESET}"
echo -e "  ${CYAN}URL          ${GREEN}${SERVICE_URL}${RESET}"
echo -e "  ${CYAN}TIER         ${GREEN}${FINAL_CPU} vCPU / ${FINAL_RAM}${RESET}"
echo ""
echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${CYAN}              CONNECTION DETAILS${RESET}"
echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${GREEN}SSH${RESET}   | WS Path: ${CYAN}/impostor-ssh${RESET}   | Port: ${CYAN}443${RESET}"
echo -e "  ${GREEN}UDPGW${RESET} | Port: ${CYAN}7300${RESET}              | Proto: ${CYAN}UDP${RESET}"
echo -e "  ${GREEN}USER${RESET}  | Name: ${CYAN}Impostor${RESET}          | Pass: ${CYAN}Impostor${RESET}"
echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

cleanup() {
    [ "${ALREADY_CLEANED:-0}" -eq 1 ] && return
    ALREADY_CLEANED=1
    rm -f build.log deploy.log
    exit 0
}
trap cleanup INT TERM EXIT

echo -e "  ${CYAN}✅ Done — copy details above. Press Ctrl+C to exit.${RESET}"
while true; do sleep 60; done

#!/bin/bash

CSV_FILE="guest.csv"

_init_csv() {
    if [ ! -f "$CSV_FILE" ]; then
        echo "-----"
        echo " 找不到 $CSV_FILE，觸發自動建立程序..."
        echo '"基礎資訊","記錄次數","時間","年齡","身高(CM)","體重(KG)","BMI","體脂(%)","肌肉量(KG)","內臟脂肪","代謝(Kcal)","舒張壓","收縮壓","心跳(BPM)","血氧(PBO2)","記錄時間"' > "$CSV_FILE"
        echo " $CSV_FILE 框架建立完成。"
    fi
}

_read_last_record() {
    local line_count=$(wc -l < "$CSV_FILE")
    if [ "$line_count" -le 1 ]; then
        _VAL_COUNT=0
        return 1 # 回傳 1 觸發 First_Run
    fi

    local raw_data=$(awk -v FPAT='([^,]*)|("[^"]+")' 'END {print $0}' "$CSV_FILE")
    eval $(echo "$raw_data" | awk -v FPAT='([^,]*)|("[^"]+")' '{
        info=$1; gsub(/^"|"$/, "", info); printf "_VAL_INFO='\''%s'\''; ", info
        count=$2; gsub(/^"|"$/, "", count); printf "_VAL_COUNT='\''%s'\''; ", count
        height=$5; gsub(/^"|"$/, "", height); printf "_VAL_HEIGHT='\''%s'\''; ", height
    }')
    return 0
}

_write_csv() {
    echo "-----"
    echo " 啟動資料自動運算與寫入引擎..."

    local record_time=$(date "+%Y%m%d%H%M%S")
    local current_date=$(date "+%Y%m%d")
    
    local dob_raw=$(awk -v FPAT='([^,]*)|("[^"]+")' 'NR==2 {gsub(/^"|"$/, "", $3); print $3}' "$CSV_FILE")
    # 若是 First_Run (Row 0) 還沒寫入 CSV，則 fallback 使用當下輸入的 $_VAL_SETTIME
    dob_raw=${dob_raw:-$_VAL_SETTIME} 
    
    local _VAL_AGE=$(( (current_date - dob_raw) / 10000 ))
    local _VAL_BMI=$(awk -v w="$_VAL_WEIGHT" -v h="$_VAL_HEIGHT" 'BEGIN { printf "%.1f", w / ((h/100)^2) }')

    printf '"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
        "$_VAL_INFO" "$_VAL_COUNT" "$_VAL_SETTIME" "$_VAL_AGE" "$_VAL_HEIGHT" "$_VAL_WEIGHT" \
        "$_VAL_BMI" "$_VAL_BODYFAT" "$_VAL_MUSCLE" "$_VAL_VISCERAL" "$_VAL_BMR" \
        "$_VAL_DIASTOLIC" "$_VAL_SYSTOLIC" "$_VAL_HR" "$_VAL_SPO2" "$record_time" >> "$CSV_FILE"

    echo " Row $_VAL_COUNT 數據寫入完成！"
}

_state_first_run() {
    while true; do
        echo "-----"
        echo " 進入首次設定引導程序..."
        echo "-----"
        
        local gender_val=""
        while true; do
            echo " 請選擇性別："
            echo " 1. 男性 (M)"
            echo " 2. 女性 (F)"
            echo " 3. 第三性 (T)"
            echo "-----"
            read -p " 輸入選項 [1-3]： " g_choice
            case "$g_choice" in
                1) gender_val="M"; break ;;
                2) gender_val="F"; break ;;
                3) gender_val="T"; break ;;
                *) echo " 無效輸入。" ;;
            esac
        done

        echo "-----"
        local dob_val yyyy mm dd
        local current_year=$(date +%Y)
        local min_year=$((current_year - 100))

        while true; do
            read -p " 請輸入出生年月日 (格式 YYYYMMDD)： " dob_val
            
            # 檢測 1：長度與純數字判斷 (正規表達式)
            if [[ ! "$dob_val" =~ ^[0-9]{8}$ ]]; then
                echo " 格式錯誤，請再輸入一次。"
                continue
            fi
            
            # 字串拆解 (Sub-string extraction)
            yyyy=${dob_val:0:4}
            mm=${dob_val:4:2}
            dd=${dob_val:6:2}
            
            # 檢測 2：年份範圍 (10# 確保 Bash 用十進位讀取，避免 08 報錯)
            if (( 10#$yyyy > current_year || 10#$yyyy < min_year )); then
                echo " 年份異常：僅接受 $min_year 至 $current_year 之間的年份。"
                continue
            fi
            
            # 檢測 3：月份與日期基礎範圍
            if (( 10#$mm < 1 || 10#$mm > 12 )); then
                echo " 月份異常：請輸入有效月份。"
                continue
            fi
            if (( 10#$dd < 1 || 10#$dd > 31 )); then
                echo " 日期異常：請輸入有效日期。"
                continue
            fi

            if ! date -d "$yyyy-$mm-$dd" >/dev/null 2>&1; then
                echo " 無效的日曆日期：該月份沒有這一天，請重新輸入。"
                continue
            fi
            
            # 通過所有防呆測試
            break
        done

        echo "-----"
        local height_val weight_val
        read -p " 請輸入身高 (cm)： " height_val
        read -p " 請輸入體重 (KG)： " weight_val

        echo "-----"
        echo " 基本資料建立完畢。"
        echo "-----"
        echo " 性別：$gender_val"
        echo " 出身年月日：$dob_val"
        echo " 身高、體重：${height_val} cm / ${weight_val} KG"
        echo "-----"
        
        read -p " 請確認基本資料是否正確？ [Y/n]： " confirm_flag
        case "$confirm_flag" in
            [Yy]* | "" )
                _VAL_INFO="${gender_val}"
                _VAL_SETTIME="${dob_val}"
                _VAL_COUNT=0
                _VAL_HEIGHT="$height_val"
                _VAL_WEIGHT="$weight_val"
                
                # 初始化細部變數
                _VAL_BODYFAT=""; _VAL_MUSCLE=""; _VAL_VISCERAL=""; _VAL_BMR=""
                _VAL_DIASTOLIC=""; _VAL_SYSTOLIC=""; _VAL_HR=""; _VAL_SPO2=""

                echo "-----"
                read -p " 是否要繼續填入更細部的身體數據（如體脂、血壓等）？ [Y/n]： " detail_flag
                case "$detail_flag" in
                    [Yy]* | "" )
                        echo "-----"
                        read -p " 體脂(%)： " _VAL_BODYFAT
                        read -p " 肌肉量(KG)： " _VAL_MUSCLE
                        read -p " 內臟脂肪： " _VAL_VISCERAL
                        read -p " 代謝(Kcal)： " _VAL_BMR
                        read -p " 舒張壓(低壓)： " _VAL_DIASTOLIC
                        read -p " 收縮壓(高壓)： " _VAL_SYSTOLIC
                        read -p " 心跳(BPM)： " _VAL_HR
                        read -p " 血氧(PBO2)： " _VAL_SPO2
                        ;;
                esac
                
                # 調用寫入引擎
                _write_csv
                break
                ;;
            * ) echo " 觸發重新輸入程序..."; sleep 1 ;;
        esac
    done
}

_state_subsequent_run() {
    while true; do
        echo "-----"
        echo " 常態寫入模組 (Subsequent_Run)"
        echo "-----"
        
        # 核心邏輯：記錄次數自動 +1
        _VAL_COUNT=$((_VAL_COUNT + 1))
        local current_date=$(date "+%Y%m%d")
        _VAL_SETTIME="$current_date"

        echo " 繼承基礎資訊: $_VAL_INFO"
        echo " 記錄當前日期: $_VAL_SETTIME"
        echo " 繼承硬體規格: 身高 $_VAL_HEIGHT cm"
        echo " 本次為第 $_VAL_COUNT 次記錄"
        echo "-----"

        # 只要求輸入變動參數
        read -p "請輸入今日體重 (KG)： " _VAL_WEIGHT

        # 初始化細部資訊防污染
        _VAL_BODYFAT=""; _VAL_MUSCLE=""; _VAL_VISCERAL=""; _VAL_BMR=""
        _VAL_DIASTOLIC=""; _VAL_SYSTOLIC=""; _VAL_HR=""; _VAL_SPO2=""

        echo ""
        read -p "是否要繼續填入更細部的身體數據？ [Y/n]： " detail_flag
        case "$detail_flag" in
            [Yy]* | "" )
                echo "-----"
                read -p " 體脂(%)： " _VAL_BODYFAT
                read -p " 肌肉量(KG)： " _VAL_MUSCLE
                read -p " 內臟脂肪： " _VAL_VISCERAL
                read -p " 代謝(Kcal)： " _VAL_BMR
                read -p " 舒張壓(低壓)： " _VAL_DIASTOLIC
                read -p " 收縮壓(高壓)： " _VAL_SYSTOLIC
                read -p " 心跳(BPM)： " _VAL_HR
                read -p " 血氧(PBO2)： " _VAL_SPO2
                ;;
        esac

        echo "-----"
        read -p " 請確認本次數據是否正確並寫入？ [Y/n]： " confirm_flag
        case "$confirm_flag" in
            [Yy]* | "" )
                _write_csv
                break
                ;;
            * )
                echo "-----"
                echo " 取消寫入，重新輸入..."
                _VAL_COUNT=$((_VAL_COUNT - 1)) # 防呆：若取消寫入，計數器必須復原
                sleep 1
                ;;
        esac
    done
}

_state_edit_record() {
    echo "-----"
    echo " 歷史記錄修改模式 (Edit_Run)"
    echo "-----"
    echo " 目前有效的記錄次數範圍：0 ~ $_VAL_COUNT"
    echo "-----"
    local target_row
    read -p " 請輸入欲修改的記錄次數 (Row ID)： " target_row
    
    # 防呆：確保輸入為數字且在合法範圍內
    if [[ "$target_row" =~ ^[0-9]+$ ]] && (( target_row >= 0 && target_row <= _VAL_COUNT )); then
        echo "-----"
        echo " 成功鎖定修改目標：Row $target_row"
        echo " 正在調用底層掃描，提取該列完整數據..."
        
        # 使用 awk 提取目標列，並用 eval 將所有欄位瞬間灌入 _E_ 開頭的變數
        local raw_target_data=$(awk -v target="$target_row" -v FPAT='([^,]*)|("[^"]+")' 'NR>1 {
            count=$2; gsub(/^"|"$/, "", count);
            if(count == target) print $0
        }' "$CSV_FILE")
        
        eval $(echo "$raw_target_data" | awk -v FPAT='([^,]*)|("[^"]+")' '{
            for(i=1; i<=16; i++) { gsub(/^"|"$/, "", $i) }
            printf "_E_INFO='\''%s'\''; ", $1
            printf "_E_COUNT='\''%s'\''; ", $2
            printf "_E_TIME='\''%s'\''; ", $3
            printf "_E_AGE='\''%s'\''; ", $4
            printf "_E_HEIGHT='\''%s'\''; ", $5
            printf "_E_WEIGHT='\''%s'\''; ", $6
            printf "_E_BMI='\''%s'\''; ", $7
            printf "_E_FAT='\''%s'\''; ", $8
            printf "_E_MUSCLE='\''%s'\''; ", $9
            printf "_E_VISCERAL='\''%s'\''; ", $10
            printf "_E_BMR='\''%s'\''; ", $11
            printf "_E_DIA='\''%s'\''; ", $12
            printf "_E_SYS='\''%s'\''; ", $13
            printf "_E_HR='\''%s'\''; ", $14
            printf "_E_SPO2='\''%s'\''; ", $15
            printf "_E_RECTIME='\''%s'\''; ", $16
        }')

        echo "-----"
        echo " 直接按 Enter 則保留括號內的 [原數值]"
        echo "-----"
        # Row 0 基礎數據修改特權管制 (追加：出生年月日物理鎖死防線)
        if [ "$target_row" -eq 0 ]; then
            read -p " 性別 [$_E_INFO]: " in_info; _E_INFO=${in_info:-$_E_INFO}
            echo " 出生年月日: $_E_TIME (底層基礎錨點，不開放修改)"
            read -p " 身高(CM) [$_E_HEIGHT]: " in_height; _E_HEIGHT=${in_height:-$_E_HEIGHT}
        else
            echo " (目前為 Row $target_row，性別/身高/出生年繼承自 Row 0，不開放修改)"
        fi

        read -p " 體重(KG) [$_E_WEIGHT]: " in_weight; _E_WEIGHT=${in_weight:-$_E_WEIGHT}
        read -p " 體脂(%) [$_E_FAT]: " in_fat; _E_FAT=${in_fat:-$_E_FAT}
        read -p " 肌肉量(KG) [$_E_MUSCLE]: " in_muscle; _E_MUSCLE=${in_muscle:-$_E_MUSCLE}
        read -p " 內臟脂肪 [$_E_VISCERAL]: " in_visceral; _E_VISCERAL=${in_visceral:-$_E_VISCERAL}
        read -p " 代謝(Kcal) [$_E_BMR]: " in_bmr; _E_BMR=${in_bmr:-$_E_BMR}
        read -p " 舒張壓(低) [$_E_DIA]: " in_dia; _E_DIA=${in_dia:-$_E_DIA}
        read -p " 收縮壓(高) [$_E_SYS]: " in_sys; _E_SYS=${in_sys:-$_E_SYS}
        read -p " 心跳(BPM) [$_E_HR]: " in_hr; _E_HR=${in_hr:-$_E_HR}
        read -p " 血氧(PBO2) [$_E_SPO2]: " in_spo2; _E_SPO2=${in_spo2:-$_E_SPO2}

        echo "-----"
        echo " 重新計算物理衍生數值..."
        # 重新計算 BMI
        _E_BMI=$(awk -v w="$_E_WEIGHT" -v h="$_E_HEIGHT" 'BEGIN { printf "%.1f", w / ((h/100)^2) }')
        
        # 重新計算年齡
        local current_date=$(date "+%Y%m%d")
        if [ "$target_row" -eq 0 ]; then
            _E_AGE=$(( (current_date - _E_TIME) / 10000 ))
        else
            local dob_row0=$(awk -v FPAT='([^,]*)|("[^"]+")' 'NR==2 {gsub(/^"|"$/, "", $3); print $3}' "$CSV_FILE")
            _E_AGE=$(( (current_date - dob_row0) / 10000 ))
        fi

        # 組裝新字串 (確保所有欄位格式對齊)
        local new_csv_line=$(printf '"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"' \
            "$_E_INFO" "$_E_COUNT" "$_E_TIME" "$_E_AGE" "$_E_HEIGHT" "$_E_WEIGHT" "$_E_BMI" "$_E_FAT" "$_E_MUSCLE" "$_E_VISCERAL" "$_E_BMR" "$_E_DIA" "$_E_SYS" "$_E_HR" "$_E_SPO2" "$_E_RECTIME")

        # 底層覆寫引擎 (Write-back)：只替換 Target Row，不動其餘架構
        awk -v target="$target_row" -v new_line="$new_csv_line" -v FPAT='([^,]*)|("[^"]+")' '
        BEGIN { OFS="," }
        NR==1 { print; next }
        {
            count=$2; gsub(/^"|"$/, "", count);
            if(count == target) print new_line;
            else print $0;
        }' "$CSV_FILE" > "${CSV_FILE}.tmp" && mv "${CSV_FILE}.tmp" "$CSV_FILE"
        
        echo " Row $target_row 數據覆寫完成！"
    else
        echo " 無效的記錄次數。"
    fi
}

_state_view_record() {
    while true; do
        echo "-----"
        echo " 歷史記錄查閱模式 (View_Run)"
        echo "-----"
        echo " 目前有效的記錄次數範圍：0 ~ $_VAL_COUNT"
        echo "-----"
        
        local target_row
        read -p " 請輸入欲查閱的記錄次數 (Row ID) [輸入 Q 返回主選單]： " target_row
        
        # 退出查閱模式的物理開關
        if [[ "$target_row" == "q" || "$target_row" == "Q" ]]; then
            echo " 關閉查閱雷達，返回主調度塔..."
            sleep 0.5
            break
        fi

        # 防呆：確保輸入為數字且在合法範圍內
        if [[ "$target_row" =~ ^[0-9]+$ ]] && (( target_row >= 0 && target_row <= _VAL_COUNT )); then
            echo "-----"
            echo " 正在調用唯讀掃描，提取 Row $target_row 完整數據..."
            
            # 使用 awk 提取目標列，用 eval 灌入 _R_ (Read) 開頭的變數
            local raw_target_data=$(awk -v target="$target_row" -v FPAT='([^,]*)|("[^"]+")' 'NR>1 {
                count=$2; gsub(/^"|"$/, "", count);
                if(count == target) print $0
            }' "$CSV_FILE")
            
            eval $(echo "$raw_target_data" | awk -v FPAT='([^,]*)|("[^"]+")' '{
                for(i=1; i<=16; i++) { gsub(/^"|"$/, "", $i) }
                printf "_R_INFO='\''%s'\''; ", $1
                printf "_R_COUNT='\''%s'\''; ", $2
                printf "_R_TIME='\''%s'\''; ", $3
                printf "_R_AGE='\''%s'\''; ", $4
                printf "_R_HEIGHT='\''%s'\''; ", $5
                printf "_R_WEIGHT='\''%s'\''; ", $6
                printf "_R_BMI='\''%s'\''; ", $7
                printf "_R_FAT='\''%s'\''; ", $8
                printf "_R_MUSCLE='\''%s'\''; ", $9
                printf "_R_VISCERAL='\''%s'\''; ", $10
                printf "_R_BMR='\''%s'\''; ", $11
                printf "_R_DIA='\''%s'\''; ", $12
                printf "_R_SYS='\''%s'\''; ", $13
                printf "_R_HR='\''%s'\''; ", $14
                printf "_R_SPO2='\''%s'\''; ", $15
                printf "_R_RECTIME='\''%s'\''; ", $16
            }')

            echo "-----"
            echo " [數據庫讀取結果 - Row $_R_COUNT]"
            echo "-----"
            # Row 0 專屬顯示標籤邏輯切換
            if [ "$_R_COUNT" -eq 0 ]; then
                echo " 出生年月日: $_R_TIME"
            else
                echo " 記錄日期: $_R_TIME"
            fi
            
            echo " 性別: $_R_INFO"
            echo " 年齡: $_R_AGE"
            echo " 身高(CM): $_R_HEIGHT"
            echo " 體重(KG): $_R_WEIGHT"
            echo " BMI: $_R_BMI"
            echo " 體脂(%): $_R_FAT"
            echo " 肌肉量(KG): $_R_MUSCLE"
            echo " 內臟脂肪: $_R_VISCERAL"
            echo " 代謝(Kcal): $_R_BMR"
            echo " 舒張壓(低): $_R_DIA"
            echo " 收縮壓(高): $_R_SYS"
            echo " 心跳(BPM): $_R_HR"
            echo " 血氧(PBO2): $_R_SPO2"
            echo " 實際記錄時間: $_R_RECTIME"
            echo "-----"
            
            read -p " 按 Enter 繼續查閱其他記錄..."
        else
            echo " 無效的記錄次數，雷達無法鎖定。"
            sleep 1
        fi
    done
}

_router_start() {
    _init_csv
    if _read_last_record; then
        # 將選單包入 while true 迴圈，確保從「查閱模式」退出後能回到主選單
        while true; do
            echo "-----"
            echo " 偵測到歷史數據。目前最大記錄次數：$_VAL_COUNT"
            echo " 準備繼承基礎資訊與身高($_VAL_HEIGHT CM)..."
            echo "-----"
            echo " 請選擇系統執行模式："
            echo " 1. 新增今日記錄 (Add New Record)"
            echo " 2. 修改歷史記錄 (Edit Old Record)"
            echo " 3. 查閱歷史記錄 (View Record)"
            echo " 4. 退出 (Exit)"
            echo "-----"

            read -p " 輸入選項 [1-4]： " run_mode
            case "$run_mode" in
                1) _state_subsequent_run; break ;; 
                2) _state_edit_record; break ;;    
                3) _state_view_record ;;  # 查閱模式不加 break，查完自動返回主調度選單
                4) clear; echo " 取消記錄，腳本結束。"; break ;;
                *) echo " 無效輸入，請重新選擇。"; sleep 1 ;;
            esac
        done
    else
        echo "-----"
        echo " 偵測為空資料表，啟動首次設定引導 (First_Run)..."
        _state_first_run
    fi
}

clear
echo "-----"
echo " 身高體重資料記錄腳本"
echo "-----"
echo " 注意事項："
echo " 1. 第一次使用必須先記錄個人基本數據資訊（例如：出生年月日、身高、體重等）"
echo " 2. 資料越詳細越好，方便長期觀察個人數據的變化。"
echo "-----"

read -p " 準備好就開始記錄你的身體數據了嗎？ [Y/n]： " start_flag
case "$start_flag" in
    [Yy]* | "" )
        _router_start ;;
    [Nn]* )
        clear; echo " 取消記錄，腳本結束。"; exit 0 ;;
    * )
        echo " 無效輸入。"; exit 1 ;;
esac
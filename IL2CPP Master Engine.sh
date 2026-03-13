#!/system/bin/sh

# =================================================
# IL2CPP MASTER ENGINE
# =================================================

# --- CONFIGURATION ---
SEARCH_ROOT="/storage/emulated/0"
OUTPUT_DIR="/storage/emulated/0"

# Dedicated Persistent Workspace (Hidden)
WORKSPACE="/storage/emulated/0/.il2cpp_workspace"
CACHE_DIR="$WORKSPACE/caches"
TMP_DIR="$WORKSPACE/tmp"

# Completely reset session memory on fresh startup
rm -rf "$TMP_DIR" 
mkdir -p "$CACHE_DIR"
mkdir -p "$TMP_DIR"

TMP_CUSTOM="$TMP_DIR/tmp_custom_search.txt"
TMP_CAT="$TMP_DIR/tmp_cat_search.txt"
SESSION_TARGETS="$TMP_DIR/session_targets.txt"
> "$SESSION_TARGETS"
# ---------------------

# =================================================
# REUSABLE CLASS INSPECTOR FUNCTION
# =================================================
inspect_class_from_list() {
    local inspect_class="$1"
    local temp_out="$TMP_DIR/nested_class_${RANDOM}.txt"
    
    clear
    echo "================================================="
    echo " 🔍 CLASS INSPECTOR: $inspect_class"
    echo "================================================="
    echo "Filter methods by Data Type:"
    echo "1) Bool"
    echo "2) Int"
    echo "3) Float"
    echo "4) Long"
    echo "5) Void"
    echo "6) String"
    echo "7) Other"
    echo "8) 🌌 Show ALL Methods"
    echo "m) 🏠 Return to Main Menu"
    echo -n "Choice (Default: 8): "
    local c_type_choice
    read c_type_choice
    
    if [ "$c_type_choice" = "m" ] || [ "$c_type_choice" = "M" ]; then 
        GO_HOME=1
        rm -f "$temp_out"
        return
    fi

    local TYPE_FILTER="ALL"
    case $c_type_choice in
        1) TYPE_FILTER="Bool" ;;
        2) TYPE_FILTER="Int" ;;
        3) TYPE_FILTER="Float" ;;
        4) TYPE_FILTER="Long" ;;
        5) TYPE_FILTER="Void" ;;
        6) TYPE_FILTER="String" ;;
        7) TYPE_FILTER="Other" ;;
        *) TYPE_FILTER="ALL" ;;
    esac

    if [ "$TYPE_FILTER" = "ALL" ]; then
        awk -F'|' -v cls="$inspect_class" '$4 == cls { print $0 }' "$TMP_MASTER_CACHE" > "$temp_out"
    else
        awk -F'|' -v cls="$inspect_class" -v type="$TYPE_FILTER" '$4 == cls && $1 == type { print $0 }' "$TMP_MASTER_CACHE" > "$temp_out"
    fi
    
    local TOTAL_CLS=$(wc -l < "$temp_out" | tr -d ' ')
    
    if [ "$TOTAL_CLS" -eq 0 ]; then
        echo "❌ No $TYPE_FILTER methods found in this Class."
        echo -n "Press [ENTER] to return..."
        read ignore_var
        rm -f "$temp_out"
        return
    fi

    local START_IDX_CLS=1
    local PAGE_SIZE_CLS=200
    
    while true; do
        local END_IDX_CLS=$((START_IDX_CLS + PAGE_SIZE_CLS - 1))
        if [ "$END_IDX_CLS" -gt "$TOTAL_CLS" ]; then END_IDX_CLS=$TOTAL_CLS; fi

        clear
        echo "================================================="
        echo " 🔍 CLASS: $inspect_class ($TYPE_FILTER)"
        echo " Showing $START_IDX_CLS to $END_IDX_CLS of $TOTAL_CLS"
        echo "================================================="
        
        local cls_idx=$START_IDX_CLS
        sed -n "${START_IDX_CLS},${END_IDX_CLS}p" "$temp_out" | while IFS='|' read -r n_type n_rva n_ns n_cls n_func; do
            n_ns=${n_ns#Namespace: }
            local b_mark=""
            if grep -Fxq "Offset: $n_rva" "$BOOKMARK_FILE" 2>/dev/null; then b_mark=" ⭐ [BOOKMARKED]"; fi
            echo "[$cls_idx]$b_mark"
            echo "    Namespace:     $n_ns"
            echo "    Class:         $n_cls"
            echo "    Function Name: $n_func"
            echo "    Offset:        $n_rva"
            echo "-------------------------------------------------"
            cls_idx=$((cls_idx+1))
        done
        
        echo "Select Targets:"
        echo "Save to Memory: '1', '1,3', '1-4', 'all'"
        echo "Bookmark to File: 'b1', 'b1,3', 'b1-4', 'ball'"
        echo "Inspect Target: 'c1' (Class), 'n1' (Namespace)"
        if [ "$END_IDX_CLS" -lt "$TOTAL_CLS" ]; then
            echo "[ENTER: Next Page | 'm': Main Menu | '#': Go Back]"
        else
            echo "['m': Main Menu | '#': Go Back]"
        fi
        echo -n "Selection: "
        local nested_sel
        read nested_sel
        
        if [ "$nested_sel" = "#" ]; then break; fi
        if [ "$nested_sel" = "m" ] || [ "$nested_sel" = "M" ]; then GO_HOME=1; break; fi
        if [ -z "$nested_sel" ] && [ "$END_IDX_CLS" -lt "$TOTAL_CLS" ]; then
            START_IDX_CLS=$((END_IDX_CLS + 1))
            continue
        fi
        
        local first_char=$(echo "$nested_sel" | cut -c1 | tr '[:upper:]' '[:lower:]')
        
        # Namespace Inspection Shortcut
        if [ "$first_char" = "n" ]; then
            local inspect_idx=$(echo "$nested_sel" | sed 's/^[nN]//')
            if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                if [ "$inspect_idx" -ge "$START_IDX_CLS" ] && [ "$inspect_idx" -le "$END_IDX_CLS" ]; then
                    local raw_data=$(sed -n "${inspect_idx}p" "$temp_out")
                    local target_ns=$(echo "$raw_data" | cut -d'|' -f3)
                    inspect_namespace_from_list "$target_ns"
                    if [ "$GO_HOME" -eq 1 ]; then break; fi
                else
                    echo "❌ Item number not on this page. Press [ENTER]."
                    read ignore_var
                fi
            else
                echo "❌ Invalid format. Use 'n1', 'n8', etc. Press [ENTER]."
                read ignore_var
            fi
            continue
        fi

        # Class Inspection Shortcut
        if [ "$first_char" = "c" ]; then
            local inspect_idx=$(echo "$nested_sel" | sed 's/^[cC]//')
            if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                if [ "$inspect_idx" -ge "$START_IDX_CLS" ] && [ "$inspect_idx" -le "$END_IDX_CLS" ]; then
                    local raw_data=$(sed -n "${inspect_idx}p" "$temp_out")
                    local target_cls=$(echo "$raw_data" | cut -d'|' -f4)
                    inspect_class_from_list "$target_cls"
                    if [ "$GO_HOME" -eq 1 ]; then break; fi
                else
                    echo "❌ Item number not on this page. Press [ENTER]."
                    read ignore_var
                fi
            else
                echo "❌ Invalid format. Use 'c1', 'c8', etc. Press [ENTER]."
                read ignore_var
            fi
            continue
        fi
        
        local is_nested_bookmark=0
        if [ "$first_char" = "b" ]; then
            is_nested_bookmark=1
            nested_sel=$(echo "$nested_sel" | sed 's/^[bB]//')
        fi
        
        local N_IDS=""
        if [ "$nested_sel" = "all" ]; then
            N_IDS=$(seq $START_IDX_CLS $END_IDX_CLS)
        else
            local normalized_nsel=$(echo "$nested_sel" | tr ',' ' ')
            for item in $normalized_nsel; do
                if echo "$item" | grep -q "-"; then
                    local start=${item%-*}
                    local end=${item#*-}
                    if [ "$start" -eq "$start" ] 2>/dev/null && [ "$end" -eq "$end" ] 2>/dev/null; then
                        local i=$start
                        while [ $i -le $end ]; do
                            N_IDS="$N_IDS $i"
                            i=$((i + 1))
                        done
                    fi
                else
                    if [ "$item" -eq "$item" ] 2>/dev/null; then
                        N_IDS="$N_IDS $item"
                    fi
                fi
            done
        fi
        
        N_IDS=$(echo "$N_IDS" | xargs -n1 2>/dev/null | sort -u -n | xargs)
        if [ -z "$N_IDS" ]; then
            echo "❌ No valid selection made. Press [ENTER]."
            read ignore_var
            continue
        fi
        
        for i in $N_IDS; do
            if [ "$i" -ge 1 ] && [ "$i" -le "$TOTAL_CLS" ]; then
                local n_raw=$(sed -n "${i}p" "$temp_out")
                local n_type=$(echo "$n_raw" | cut -d'|' -f1)
                local n_rva=$(echo "$n_raw" | cut -d'|' -f2)
                local n_ns=$(echo "$n_raw" | cut -d'|' -f3)
                local n_cls=$(echo "$n_raw" | cut -d'|' -f4)
                local n_func=$(echo "$n_raw" | cut -d'|' -f5)
                n_ns=${n_ns#Namespace: }

                if [ "$is_nested_bookmark" -eq 1 ]; then
                    echo "Type: $n_type" >> "$BOOKMARK_FILE"
                    echo "Namespace: $n_ns" >> "$BOOKMARK_FILE"
                    echo "Class: $n_cls" >> "$BOOKMARK_FILE"
                    echo "Function Name: $n_func" >> "$BOOKMARK_FILE"
                    echo "Offset: $n_rva" >> "$BOOKMARK_FILE"
                    echo "-------------------------------------------------" >> "$BOOKMARK_FILE"
                else
                    echo "Type: $n_type" >> "$SESSION_TARGETS"
                    echo "Namespace: $n_ns" >> "$SESSION_TARGETS"
                    echo "Class: $n_cls" >> "$SESSION_TARGETS"
                    echo "Function Name: $n_func" >> "$SESSION_TARGETS"
                    echo "Offset: $n_rva" >> "$SESSION_TARGETS"
                    echo "-------------------------------------------------" >> "$SESSION_TARGETS"
                fi
            fi
        done
        
        if [ "$is_nested_bookmark" -eq 1 ]; then
            echo -e "\n⭐ Targets successfully BOOKMARKED!"
            sleep 1
        else
            echo -e "\n✅ Targets successfully saved to session memory!"
            echo -n "Press [ENTER] to continue inspecting class..."
            read ignore_var
        fi
    done
    rm -f "$temp_out"
}

# =================================================
# REUSABLE NAMESPACE INSPECTOR FUNCTION
# =================================================
inspect_namespace_from_list() {
    local inspect_ns="$1"
    local temp_out="$TMP_DIR/nested_ns_${RANDOM}.txt"
    
    clear
    echo "================================================="
    echo " 🌌 NAMESPACE INSPECTOR: $inspect_ns"
    echo "================================================="
    echo "Filter methods by Data Type:"
    echo "1) Bool"
    echo "2) Int"
    echo "3) Float"
    echo "4) Long"
    echo "5) Void"
    echo "6) String"
    echo "7) Other"
    echo "8) 🌌 Show ALL Methods"
    echo "m) 🏠 Return to Main Menu"
    echo -n "Choice (Default: 8): "
    local n_type_choice
    read n_type_choice
    
    if [ "$n_type_choice" = "m" ] || [ "$n_type_choice" = "M" ]; then 
        GO_HOME=1
        rm -f "$temp_out"
        return
    fi

    local TYPE_FILTER="ALL"
    case $n_type_choice in
        1) TYPE_FILTER="Bool" ;;
        2) TYPE_FILTER="Int" ;;
        3) TYPE_FILTER="Float" ;;
        4) TYPE_FILTER="Long" ;;
        5) TYPE_FILTER="Void" ;;
        6) TYPE_FILTER="String" ;;
        7) TYPE_FILTER="Other" ;;
        *) TYPE_FILTER="ALL" ;;
    esac

    if [ "$TYPE_FILTER" = "ALL" ]; then
        awk -F'|' -v ns="$inspect_ns" '$3 == ns { print $0 }' "$TMP_MASTER_CACHE" > "$temp_out"
    else
        awk -F'|' -v ns="$inspect_ns" -v type="$TYPE_FILTER" '$3 == ns && $1 == type { print $0 }' "$TMP_MASTER_CACHE" > "$temp_out"
    fi
    
    local TOTAL_NS=$(wc -l < "$temp_out" | tr -d ' ')
    
    if [ "$TOTAL_NS" -eq 0 ]; then
        echo "❌ No $TYPE_FILTER methods found in this Namespace."
        echo -n "Press [ENTER] to return..."
        read ignore_var
        rm -f "$temp_out"
        return
    fi

    local START_IDX_NS=1
    local PAGE_SIZE_NS=200
    
    while true; do
        local END_IDX_NS=$((START_IDX_NS + PAGE_SIZE_NS - 1))
        if [ "$END_IDX_NS" -gt "$TOTAL_NS" ]; then END_IDX_NS=$TOTAL_NS; fi

        clear
        echo "================================================="
        echo " 🌌 NAMESPACE: $inspect_ns ($TYPE_FILTER)"
        echo " Showing $START_IDX_NS to $END_IDX_NS of $TOTAL_NS"
        echo "================================================="
        
        local ns_idx=$START_IDX_NS
        sed -n "${START_IDX_NS},${END_IDX_NS}p" "$temp_out" | while IFS='|' read -r n_type n_rva n_ns n_cls n_func; do
            n_ns=${n_ns#Namespace: }
            local b_mark=""
            if grep -Fxq "Offset: $n_rva" "$BOOKMARK_FILE" 2>/dev/null; then b_mark=" ⭐ [BOOKMARKED]"; fi
            echo "[$ns_idx]$b_mark"
            echo "    Namespace:     $n_ns"
            echo "    Class:         $n_cls"
            echo "    Function Name: $n_func"
            echo "    Offset:        $n_rva"
            echo "-------------------------------------------------"
            ns_idx=$((ns_idx+1))
        done
        
        echo "Select Targets:"
        echo "Save to Memory: '1', '1,3', '1-4', 'all'"
        echo "Bookmark to File: 'b1', 'b1,3', 'b1-4', 'ball'"
        echo "Inspect Target: 'c1' (Class), 'n1' (Namespace)"
        if [ "$END_IDX_NS" -lt "$TOTAL_NS" ]; then
            echo "[ENTER: Next Page | 'm': Main Menu | '#': Go Back]"
        else
            echo "['m': Main Menu | '#': Go Back]"
        fi
        echo -n "Selection: "
        local nested_sel
        read nested_sel
        
        if [ "$nested_sel" = "#" ]; then break; fi
        if [ "$nested_sel" = "m" ] || [ "$nested_sel" = "M" ]; then GO_HOME=1; break; fi
        if [ -z "$nested_sel" ] && [ "$END_IDX_NS" -lt "$TOTAL_NS" ]; then
            START_IDX_NS=$((END_IDX_NS + 1))
            continue
        fi
        
        local first_char=$(echo "$nested_sel" | cut -c1 | tr '[:upper:]' '[:lower:]')
        
        # Namespace Inspection Shortcut
        if [ "$first_char" = "n" ]; then
            local inspect_idx=$(echo "$nested_sel" | sed 's/^[nN]//')
            if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                if [ "$inspect_idx" -ge "$START_IDX_NS" ] && [ "$inspect_idx" -le "$END_IDX_NS" ]; then
                    local raw_data=$(sed -n "${inspect_idx}p" "$temp_out")
                    local target_ns=$(echo "$raw_data" | cut -d'|' -f3)
                    inspect_namespace_from_list "$target_ns"
                    if [ "$GO_HOME" -eq 1 ]; then break; fi
                else
                    echo "❌ Item number not on this page. Press [ENTER]."
                    read ignore_var
                fi
            else
                echo "❌ Invalid format. Use 'n1', 'n8', etc. Press [ENTER]."
                read ignore_var
            fi
            continue
        fi

        # Class Inspection Shortcut
        if [ "$first_char" = "c" ]; then
            local inspect_idx=$(echo "$nested_sel" | sed 's/^[cC]//')
            if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                if [ "$inspect_idx" -ge "$START_IDX_NS" ] && [ "$inspect_idx" -le "$END_IDX_NS" ]; then
                    local raw_data=$(sed -n "${inspect_idx}p" "$temp_out")
                    local target_cls=$(echo "$raw_data" | cut -d'|' -f4)
                    inspect_class_from_list "$target_cls"
                    if [ "$GO_HOME" -eq 1 ]; then break; fi
                else
                    echo "❌ Item number not on this page. Press [ENTER]."
                    read ignore_var
                fi
            else
                echo "❌ Invalid format. Use 'c1', 'c8', etc. Press [ENTER]."
                read ignore_var
            fi
            continue
        fi
        
        local is_nested_bookmark=0
        if [ "$first_char" = "b" ]; then
            is_nested_bookmark=1
            nested_sel=$(echo "$nested_sel" | sed 's/^[bB]//')
        fi
        
        local N_IDS=""
        if [ "$nested_sel" = "all" ]; then
            N_IDS=$(seq $START_IDX_NS $END_IDX_NS)
        else
            local normalized_nsel=$(echo "$nested_sel" | tr ',' ' ')
            for item in $normalized_nsel; do
                if echo "$item" | grep -q "-"; then
                    local start=${item%-*}
                    local end=${item#*-}
                    if [ "$start" -eq "$start" ] 2>/dev/null && [ "$end" -eq "$end" ] 2>/dev/null; then
                        local i=$start
                        while [ $i -le $end ]; do
                            N_IDS="$N_IDS $i"
                            i=$((i + 1))
                        done
                    fi
                else
                    if [ "$item" -eq "$item" ] 2>/dev/null; then
                        N_IDS="$N_IDS $item"
                    fi
                fi
            done
        fi
        
        N_IDS=$(echo "$N_IDS" | xargs -n1 2>/dev/null | sort -u -n | xargs)
        if [ -z "$N_IDS" ]; then
            echo "❌ No valid selection made. Press [ENTER]."
            read ignore_var
            continue
        fi
        
        for i in $N_IDS; do
            if [ "$i" -ge 1 ] && [ "$i" -le "$TOTAL_NS" ]; then
                local n_raw=$(sed -n "${i}p" "$temp_out")
                local n_type=$(echo "$n_raw" | cut -d'|' -f1)
                local n_rva=$(echo "$n_raw" | cut -d'|' -f2)
                local n_ns=$(echo "$n_raw" | cut -d'|' -f3)
                local n_cls=$(echo "$n_raw" | cut -d'|' -f4)
                local n_func=$(echo "$n_raw" | cut -d'|' -f5)
                n_ns=${n_ns#Namespace: }

                if [ "$is_nested_bookmark" -eq 1 ]; then
                    echo "Type: $n_type" >> "$BOOKMARK_FILE"
                    echo "Namespace: $n_ns" >> "$BOOKMARK_FILE"
                    echo "Class: $n_cls" >> "$BOOKMARK_FILE"
                    echo "Function Name: $n_func" >> "$BOOKMARK_FILE"
                    echo "Offset: $n_rva" >> "$BOOKMARK_FILE"
                    echo "-------------------------------------------------" >> "$BOOKMARK_FILE"
                else
                    echo "Type: $n_type" >> "$SESSION_TARGETS"
                    echo "Namespace: $n_ns" >> "$SESSION_TARGETS"
                    echo "Class: $n_cls" >> "$SESSION_TARGETS"
                    echo "Function Name: $n_func" >> "$SESSION_TARGETS"
                    echo "Offset: $n_rva" >> "$SESSION_TARGETS"
                    echo "-------------------------------------------------" >> "$SESSION_TARGETS"
                fi
            fi
        done
        
        if [ "$is_nested_bookmark" -eq 1 ]; then
            echo -e "\n⭐ Targets successfully BOOKMARKED!"
            sleep 1
        else
            echo -e "\n✅ Targets successfully saved to session memory!"
            echo -n "Press [ENTER] to continue..."
            read ignore_var
        fi
    done
    rm -f "$temp_out"
}

# =================================================
# LUA GENERATION FUNCTION (MASTER PATCH DASHBOARD)
# =================================================
generate_lua_script() {
    TARGET_COUNT=0
    if [ -f "$SESSION_TARGETS" ]; then
        TARGET_COUNT=$(grep -c "^Offset:" "$SESSION_TARGETS")
    fi

    if [ "$TARGET_COUNT" -eq 0 ]; then
        echo "❌ No targets ready! Hunt and select targets first."
        echo -n "Press [ENTER] to return..."
        read ignore_var
        return
    fi

    clear
    echo "================================================="
    echo "           📜 INTERACTIVE LUA BUILDER            "
    echo "================================================="
    echo "Architecture Selection:"
    echo "1) ARM32 (Index 1)"
    echo "2) ARM64 (Index 2)"
    echo "m) 🏠 Main Menu"
    echo -n "Choice (1 or 2): "
    read arch_choice
    
    if [ "$arch_choice" = "m" ] || [ "$arch_choice" = "M" ]; then return; fi

    arch_idx=1
    if [ "$arch_choice" = "2" ]; then arch_idx=2; fi

    LUA_OUT="$OUTPUT_DIR/${GAME_NAME}_ModMenu.lua"

    # Extract unique targets and index them into a patch list
    awk '
        /^Type: / { type = substr($0, 7) }
        /^Namespace: / { ns = substr($0, 12) }
        /^Class: / { cls = substr($0, 8) }
        /^Function Name: / { func_name = substr($0, 16) }
        /^Offset: / { 
            offset = substr($0, 9)
            if (!seen[offset]++) {
                count++
                print count "|" offset "|" type "|" func_name "|" ns "|" cls "|PENDING"
            }
        }
    ' "$SESSION_TARGETS" > "$TMP_DIR/patch_list.txt"

    TOTAL_PATCH=$(wc -l < "$TMP_DIR/patch_list.txt" | tr -d ' ')
    START_IDX_PATCH=1
    PAGE_SIZE_PATCH=50

    # ---------------------------------------------------------
    # MASTER PATCH DASHBOARD LOOP
    # ---------------------------------------------------------
    while true; do
        END_IDX_PATCH=$((START_IDX_PATCH + PAGE_SIZE_PATCH - 1))
        if [ "$END_IDX_PATCH" -gt "$TOTAL_PATCH" ]; then END_IDX_PATCH=$TOTAL_PATCH; fi

        clear
        echo "=========================================================================="
        echo " 🛠️ MASTER PATCH DASHBOARD (Showing $START_IDX_PATCH to $END_IDX_PATCH of $TOTAL_PATCH)"
        echo "=========================================================================="
        
        sed -n "${START_IDX_PATCH},${END_IDX_PATCH}p" "$TMP_DIR/patch_list.txt" | while IFS='|' read -r id offset type func ns cls hexval; do
            if [ "$hexval" = "PENDING" ]; then
                status="❌ [PENDING]"
                display_hex=""
            else
                status="✅ [PATCHED]"
                display_hex=" -> $hexval"
            fi
            
            # Print the full function name, no truncation, let Termux wrap it naturally
            printf "[%02d] %-12s | %-5s | %s%s\n" "$id" "$status" "$type" "$func" "$display_hex"
        done
        
        echo "--------------------------------------------------------------------------"
        echo "Select targets to patch together (e.g., '1', '1,3', '1-4', 'all')"
        if [ "$END_IDX_PATCH" -lt "$TOTAL_PATCH" ]; then
            echo "Type 'F' to Finish & Generate | ENTER for Next Page | 'm' to Abort"
        else
            echo "Type 'F' to Finish & Generate | 'm' to Abort"
        fi
        echo -n "Selection: "
        read patch_sel
        
        if [ "$patch_sel" = "m" ] || [ "$patch_sel" = "M" ]; then return; fi
        if [ "$patch_sel" = "f" ] || [ "$patch_sel" = "F" ]; then break; fi
        if [ -z "$patch_sel" ] && [ "$END_IDX_PATCH" -lt "$TOTAL_PATCH" ]; then
            START_IDX_PATCH=$((END_IDX_PATCH + 1))
            continue
        fi
        if [ -z "$patch_sel" ]; then continue; fi

        # Parse target selection for patching
        P_IDS=""
        if [ "$patch_sel" = "all" ]; then
            P_IDS=$(seq $START_IDX_PATCH $END_IDX_PATCH)
        else
            normalized_psel=$(echo "$patch_sel" | tr ',' ' ')
            for item in $normalized_psel; do
                if echo "$item" | grep -q "-"; then
                    start=${item%-*}
                    end=${item#*-}
                    if [ "$start" -eq "$start" ] 2>/dev/null && [ "$end" -eq "$end" ] 2>/dev/null; then
                        i=$start
                        while [ $i -le $end ]; do
                            P_IDS="$P_IDS $i"
                            i=$((i + 1))
                        done
                    fi
                else
                    if [ "$item" -eq "$item" ] 2>/dev/null; then
                        P_IDS="$P_IDS $item"
                    fi
                fi
            done
        fi
        
        P_IDS=$(echo "$P_IDS" | xargs -n1 2>/dev/null | sort -u -n | xargs)
        if [ -z "$P_IDS" ]; then
            echo "❌ Invalid selection."
            sleep 1
            continue
        fi

        # ---------------------------------------------------------
        # BATCH HEX ASSIGNMENT MENU
        # ---------------------------------------------------------
        clear
        echo "================================================="
        echo " 🎯 BATCH PATCHING TARGETS: $P_IDS"
        echo "================================================="
        selected_hex=""
        hex_opt=""

        if [ "$arch_choice" = "2" ]; then
            echo "1) True         (h 200080D2C0035FD6)"
            echo "2) False        (h 000080D2C0035FD6)"
            echo "3) Int: 1000    (h 007D80D2C0035FD6)"
            echo "4) Int: 10000   (h 00E284D2C0035FD6)"
            echo "5) Int: MAX     (h E07B40B2C0035FD6)"
            echo "6) Float: 0     (h E003271EC0035FD6)"
            echo "7) Float: 1     (h 00102E1EC0035FD6)"
            echo "8) Float: 90    (h 8856A8520001271EC0035FD6)"
            echo "9) Float: -90   (h 88A9B7520001271EC0035FD6)"
            echo "10) Float: Oth  (h 5837B197E6FEFF97A00100B4)"
            echo "11) RET         (h C0035FD6C0035FD6)"
            echo "12) NOP         (h 1F2003D51F2003D5)"
            echo "C) Custom HEX Input"
            echo "b) 🔙 Cancel & Go Back to Dashboard"
            echo -n "Choice: "; read hex_opt
            case $hex_opt in
                1) selected_hex="h 200080D2C0035FD6" ;;
                2) selected_hex="h 000080D2C0035FD6" ;;
                3) selected_hex="h 007D80D2C0035FD6" ;;
                4) selected_hex="h 00E284D2C0035FD6" ;;
                5) selected_hex="h E07B40B2C0035FD6" ;;
                6) selected_hex="h E003271EC0035FD6" ;;
                7) selected_hex="h 00102E1EC0035FD6" ;;
                8) selected_hex="h 8856A8520001271EC0035FD6" ;;
                9) selected_hex="h 88A9B7520001271EC0035FD6" ;;
                10) selected_hex="h 5837B197E6FEFF97A00100B4" ;;
                11) selected_hex="h C0035FD6C0035FD6" ;;
                12) selected_hex="h 1F2003D51F2003D5" ;;
                B|b) continue ;;
                C|c) echo -n "Enter Custom Hex (e.g. h FFFFFFFF): "; read selected_hex ;;
                *) echo -n "Enter Custom Hex: "; read selected_hex ;;
            esac
        else
            echo "1) True         (h 0100A0E31EFF2FE1)"
            echo "2) False        (h 0000A0E31EFF2FE1)"
            echo "3) Int: 1000    (h E80300E31EFF2FE1)"
            echo "4) Int: 10000   (h 100702E31EFF2FE1)"
            echo "5) Int: MAX     (h FF0F47E31EFF2FE1)"
            echo "6) Float: 0     (h 0000A0E31EFF2FE1)"
            echo "7) Float: 1     (h 800F43E31EFF2FE1)"
            echo "8) Float: 100   (h C80244E31EFF2FE1)"
            echo "9) Float: 2000  (h FA0444E31EFF2FE1)"
            echo "10) RET         (h 1EFF2FE11EFF2FE1)"
            echo "11) NOP         (h 00F020E300F020E3)"
            echo "C) Custom HEX Input"
            echo "b) 🔙 Cancel & Go Back to Dashboard"
            echo -n "Choice: "; read hex_opt
            case $hex_opt in
                1) selected_hex="h 0100A0E31EFF2FE1" ;;
                2) selected_hex="h 0000A0E31EFF2FE1" ;;
                3) selected_hex="h E80300E31EFF2FE1" ;;
                4) selected_hex="h 100702E31EFF2FE1" ;;
                5) selected_hex="h FF0F47E31EFF2FE1" ;;
                6) selected_hex="h 0000A0E31EFF2FE1" ;;
                7) selected_hex="h 800F43E31EFF2FE1" ;;
                8) selected_hex="h C80244E31EFF2FE1" ;;
                9) selected_hex="h FA0444E31EFF2FE1" ;;
                10) selected_hex="h 1EFF2FE11EFF2FE1" ;;
                11) selected_hex="h 00F020E300F020E3" ;;
                B|b) continue ;;
                C|c) echo -n "Enter Custom Hex: "; read selected_hex ;;
                *) echo -n "Enter Custom Hex: "; read selected_hex ;;
            esac
        fi

        # Apply Hex to selected targets and overwrite list
        if [ -n "$selected_hex" ]; then
            > "$TMP_DIR/patch_list_new.txt"
            while IFS='|' read -r id offset type func ns cls hexval; do
                is_selected=0
                for p_id in $P_IDS; do
                    if [ "$id" -eq "$p_id" ]; then
                        is_selected=1
                        break
                    fi
                done
                if [ "$is_selected" -eq 1 ]; then
                    echo "$id|$offset|$type|$func|$ns|$cls|$selected_hex" >> "$TMP_DIR/patch_list_new.txt"
                else
                    echo "$id|$offset|$type|$func|$ns|$cls|$hexval" >> "$TMP_DIR/patch_list_new.txt"
                fi
            done < "$TMP_DIR/patch_list.txt"
            mv "$TMP_DIR/patch_list_new.txt" "$TMP_DIR/patch_list.txt"
        fi
    done
    # ---------------------------------------------------------

    # Wipe strings clean to prevent memory leaks from old generated files
    LUA_OFFSETS=""
    LUA_CHEATS=""
    LUA_CHEAT_LIST=""
    
    # Process only PATCHED targets into the final Lua format
    while IFS='|' read -r id offset_val type_val current_func_name c_ns c_cls hexval; do
        if [ "$hexval" != "PENDING" ] && [ -n "$hexval" ]; then
            safe_func_name=$(echo "$current_func_name" | sed 's/"/\\"/g') 
            lua_key="[ $offset_val ] $safe_func_name"

            LUA_OFFSETS="${LUA_OFFSETS}\n    [\"${lua_key}\"] = ${offset_val},"
            
            # Note the updated 'on' and 'off' functions passing the 'name' parameter for Toasts
            LUA_CHEATS="${LUA_CHEATS}\n     [\"${lua_key}\"] = {\n         offset = offsets[\"${lua_key}\"],\n         on = function (name) applyPatchAndStoreOriginal(offsets[\"${lua_key}\"], '${hexval}', name) end,\n         off = function (name) restoreOriginal(offsets[\"${lua_key}\"], name) end,\n     },"
            LUA_CHEAT_LIST="${LUA_CHEAT_LIST}\n    \"${lua_key}\","
        fi
    done < "$TMP_DIR/patch_list.txt"

    if [ -z "$LUA_CHEAT_LIST" ]; then
        echo "❌ No targets were patched! Script generation aborted."
        sleep 2
        return
    fi

    # =========================================================
    # UPGRADED LUA TEMPLATE
    # =========================================================
    cat <<EOF > "$LUA_OUT"
-- Define Game Guardian and library name
local gg = gg
local libName = 'libil2cpp.so'
local state = {on = ' [ 🟢 ON ] ', off = ' [ 🔴 OFF ] '}

-- Store original values for restoration
local originalValues = {}

-- Define offsets
local offsets = {$(echo -e "$LUA_OFFSETS")
}

-- Ordered list of cheats
local cheatList = {$(echo -e "$LUA_CHEAT_LIST")
}

-- Function to dynamically get base address
local function getBaseAddress()
    local ranges = gg.getRangesList(libName)
    if #ranges == 0 then
        gg.alert('❌ libil2cpp.so not found! Make sure the game is running.')
        os.exit()
    end
    
    -- Verification info for debugging / architecture
    local info = gg.getTargetInfo()
    local is64Bit = info and info.x64
    
    return ranges[$arch_idx].start
end

-- Function to apply a memory patch, store original, and show a toast
local function applyPatchAndStoreOriginal(offset, hex, cheatName)
    local addr = getBaseAddress()
    local originalValue = gg.getValues({{address = addr + offset, flags = gg.TYPE_QWORD}})[1].value
    originalValues[offset] = originalValue
    
    local formattedHex = hex:gsub(' ', '') 
    gg.setValues({{
        address = addr + offset,
        flags = gg.TYPE_QWORD,
        value = formattedHex,
    }})
    gg.toast('✅ Activated: ' .. cheatName)
end

-- Function to restore original value and show a toast
local function restoreOriginal(offset, cheatName)
    local originalValue = originalValues[offset]
    if originalValue then
        local addr = getBaseAddress()
        gg.setValues({{
            address = addr + offset,
            flags = gg.TYPE_QWORD,
            value = originalValue,
        }})
        originalValues[offset] = nil
        gg.toast('❌ Deactivated: ' .. cheatName)
    end
end

-- Get state of cheat
local function getState(item)
  return (item.state) and state.on or state.off
end

-- Set state of cheat
local function setState(item, cheatName)
  if (item.state) then
    item.off(cheatName) 
    return false
  end
  item.on(cheatName)
  return true
end

-- Define cheat functions
local cheats = {$(echo -e "$LUA_CHEATS")
}

gg.alert('Script Created By: VoidBlackZero')

-- Main menu function
local function main()
    local menuItems = {}
    local cheatKeys = {}
    
    for i, cheatName in ipairs(cheatList) do
        local cheat = cheats[cheatName]
        table.insert(menuItems, i .. ". " .. getState(cheat) .. cheatName)
        table.insert(cheatKeys, cheatName)
    end
    table.insert(menuItems, ' [ 🚪 ] Exit Mod Menu')

    local menu = gg.multiChoice(menuItems, nil, "$GAME_NAME - VoidBlackZero's Mod Menu")
    if (not menu) then return end
    
    for i, cheatName in ipairs(cheatKeys) do
        if (menu[i]) then 
            cheats[cheatName].state = setState(cheats[cheatName], cheatName) 
        end
    end
    
    if (menu[#menuItems]) then 
        gg.hideUiButton()
        gg.toast('Script Exited. Goodbye!')
        os.exit() 
    end
end

-- UI Initialization
gg.toast('🚀 Script Loaded! Tap the Sx button to open the menu.')
gg.showUiButton()

-- Main listener loop for the floating button
while true do
    if gg.isClickedUiButton() then
        main()
    end
    gg.sleep(100)
end
EOF

    clear
    echo "================================================="
    echo "✅ SUCCESS: Pro Lua Script Built!"
    echo "📂 Saved to: $LUA_OUT"
    echo "================================================="
    echo -n "Press [ENTER] to return to the Main Menu..."
    read ignore_var
}
# =================================================

# OUTER LOOP: Project Manager (New/Existing)
while true; do
    clear 
    
    echo "================================================="
    echo "         IL2CPP MASTER ENGINE                    "
    echo "================================================="

    GAME_NAME=""
    TMP_MASTER_CACHE=""
    BOOKMARK_FILE=""

    echo "               PROJECT MANAGER                   "
    echo "================================================="
    echo "1) 📂 Load Existing Project"
    echo "2) ➕ Build New Project"
    echo "================================================="
    echo -n "Enter choice: "
    read project_choice

    if [ "$project_choice" = "1" ]; then
        echo -e "\nLooking for saved projects..."
        caches=$(ls "$CACHE_DIR"/*.txt 2>/dev/null | grep -v "_bookmarks.txt")
        
        if [ -z "$caches" ]; then
            echo "❌ No saved projects found! Please build a new one."
            echo -n "Press [ENTER] to continue..."
            read ignore_var
            continue
        fi

        echo -e "\nSelect a saved project to load:"
        i=1
        IFS=$'\n'
        for c in $caches; do
            base_name=$(basename "$c" .txt)
            echo "$i) $base_name"
            eval "cache_$i=\"$c\""
            eval "name_$i=\"$base_name\""
            i=$((i+1))
        done
        unset IFS

        echo -n -e "\nEnter project number: "
        read cache_num
        eval "TMP_MASTER_CACHE=\$cache_$cache_num"
        eval "GAME_NAME=\$name_$cache_num"

        if [ ! -f "$TMP_MASTER_CACHE" ]; then
            echo "Invalid selection. Press [ENTER] to try again."
            read ignore_var
            continue
        fi
        
        BOOKMARK_FILE="$CACHE_DIR/${GAME_NAME}_bookmarks.txt"
        touch "$BOOKMARK_FILE"
        echo "✅ Loaded workspace for: $GAME_NAME"

    elif [ "$project_choice" = "2" ]; then
        echo -e "\nScanning for .cs dump files..."
        files=$(find "$SEARCH_ROOT" -name "*.cs" -not -path "*/Android/*" 2>/dev/null)

        if [ -z "$files" ]; then
            echo "❌ No .cs files found! Make sure your dump is in /storage/emulated/0"
            echo -n "Press [ENTER] to continue..."
            read ignore_var
            continue
        fi

        echo -e "\nSelect a dump.cs file to analyze:"
        i=1
        IFS=$'\n'
        for f in $files; do
            echo "$i) $f"
            eval "file_$i=\"$f\""
            i=$((i+1))
        done
        unset IFS

        echo -n -e "\nEnter file number: "
        read dump_num
        eval "SELECTED_FILE=\$file_$dump_num"

        if [ ! -f "$SELECTED_FILE" ]; then
            echo "Invalid selection. Press [ENTER] to try again."
            read ignore_var
            continue
        fi

        echo -n -e "\nEnter a name for this project (No Spaces! e.g., SubwaySurfers): "
        read RAW_GAME_NAME
        RAW_GAME_NAME=$(echo "$RAW_GAME_NAME" | tr -d ' ')
        if [ -z "$RAW_GAME_NAME" ]; then RAW_GAME_NAME="UnknownGame"; fi

        echo -n "Enter the project version (e.g., v1.2.4 or 64bit): "
        read GAME_VERSION
        GAME_VERSION=$(echo "$GAME_VERSION" | tr -d ' ')
        if [ -z "$GAME_VERSION" ]; then GAME_VERSION="v1"; fi

        GAME_NAME="${RAW_GAME_NAME}_${GAME_VERSION}"
        TMP_MASTER_CACHE="$CACHE_DIR/${GAME_NAME}.txt"
        BOOKMARK_FILE="$CACHE_DIR/${GAME_NAME}_bookmarks.txt"
        touch "$BOOKMARK_FILE"

        echo -e "\n================================================="
        echo " ⚡ BUILDING MASTER CACHE (Please wait a few secs) "
        echo "================================================="
        
        awk '
            BEGIN { IGNORECASE=1 }
            
            /^\/\/ Namespace:/ { 
                last_ns = $0
                sub(/^\/\/ Namespace: /, "", last_ns) 
                sub(/^\/\/ /, "", last_ns)
            }
            /\/\/ TypeDefIndex:/ { 
                if ($0 ~ /class|struct|interface/) {
                    last_class = $0
                    gsub(/ \/\/ TypeDefIndex:.*$/, "", last_class)
                    sub(/ *:.*$/, "", last_class)
                    sub(/[ \t]+$/, "", last_class)
                    n = split(last_class, arr, " ")
                    last_class = arr[n]
                }
            }
            /^[ \t]*\/\/ RVA: 0x/ { rva = $3; next }
            {
                if (rva != "") {
                    signature = $0
                    sub(/\(.*$/, "", signature) # Remove arguments to find true return type
                    
                    type = "Other"
                    if (signature ~ /(^|[ \t])bool[ \t]/) type = "Bool"
                    else if (signature ~ /(^|[ \t])int[ \t]/) type = "Int"
                    else if (signature ~ /(^|[ \t])long[ \t]/) type = "Long"
                    else if (signature ~ /(^|[ \t])float[ \t]/) type = "Float"
                    else if (signature ~ /(^|[ \t])void[ \t]/) type = "Void"
                    else if (signature ~ /(^|[ \t])string[ \t]/) type = "String"
                    
                    func_name = $0
                    gsub(/^[ \t]+/, "", func_name)
                    print type "|" rva "|" last_ns "|" last_class "|" func_name
                }
                rva = "" # Reset for next
            }
        ' "$SELECTED_FILE" > "$TMP_MASTER_CACHE"

        echo "✅ Project built and saved: $GAME_NAME"

    else
        continue
    fi

    # INNER LOOP: The Main Menu
    while true; do
        GO_HOME=0
        clear 

        TARGET_COUNT=0
        if [ -f "$SESSION_TARGETS" ]; then
            TARGET_COUNT=$(grep -c "^Offset:" "$SESSION_TARGETS")
        fi

        echo "================================================="
        printf "%-28s %20s\n" "$GAME_NAME" "($TARGET_COUNT targets ready)"
        echo "================================================="
        echo "1) 🎯 PRECISION SEARCH"
        echo "2) 🚥 States & Bools"
        echo "3) 💰 Economy & Stats"
        echo "4) ⚔️ Game Flow"
        echo "5) 🛒 Monetization & IAP"
        echo "6) 📡 Network Topologies"
        echo "7) 🏃 Physics & Movement"
        echo "8) 🛡️ Security & Anti-Cheat"
        echo "9) 📂 BROWSE & FILTER BY CLASS/TYPE"
        echo "-------------------------------------------------"
        echo "B) ⭐ VIEW / MANAGE BOOKMARKS"
        echo "E) 💾 EXPORT TARGETS TO TEXT FILE"
        echo "L) 📜 GENERATE LUA SCRIPT ($TARGET_COUNT targets ready)"
        echo "H) 📖 HELP / HOW TO USE"
        echo "R) 🔄 SWITCH PROJECT (Change Game)"
        echo "0) ❌ EXIT"
        echo "================================================="
        echo -n "Enter choice: "
        read mode_choice

        if [ "$mode_choice" = "R" ] || [ "$mode_choice" = "r" ]; then break; fi
        if [ "$mode_choice" = "0" ]; then rm -rf "$TMP_DIR"; echo "Exiting tool..."; exit 0; fi

        # Early validation lock - Prevents the script from falling into the wrong logic!
        case $mode_choice in
            1|2|3|4|5|6|7|8|9|B|b|E|e|L|l|H|h) ;;
            *) echo "❌ Invalid choice. Try again."; sleep 1; continue ;;
        esac

        # -------------------------------------------------------------
        # OPTION B: MANAGE BOOKMARKS
        # -------------------------------------------------------------
        if [ "$mode_choice" = "B" ] || [ "$mode_choice" = "b" ]; then
            if [ ! -s "$BOOKMARK_FILE" ]; then
                echo "❌ No bookmarks found for $GAME_NAME!"
                echo -n "Press [ENTER] to return..."
                read ignore_var
                continue
            fi
            
            while true; do
                clear
                echo "================================================="
                echo "             ⭐ BOOKMARKED TARGETS               "
                echo "================================================="
                
                awk '
                    /^Type: / { type = substr($0, 7) }
                    /^Namespace: / { ns = substr($0, 12) }
                    /^Class: / { cls = substr($0, 8) }
                    /^Function Name: / { func_name = substr($0, 16) }
                    /^Offset: / { 
                        offset = substr($0, 9)
                        print type "|" offset "|" ns "|" cls "|" func_name
                    }
                ' "$BOOKMARK_FILE" > "$TMP_DIR/parsed_bookmarks.txt"
                
                TOTAL_BM=$(wc -l < "$TMP_DIR/parsed_bookmarks.txt" | tr -d ' ')
                if [ "$TOTAL_BM" -eq 0 ]; then echo "Bookmarks are empty."; read ignore_var; break; fi
                
                item_idx=1
                while IFS='|' read -r b_type b_offset b_ns b_cls b_func; do
                    echo "[$item_idx]"
                    echo "    Namespace:     $b_ns"
                    echo "    Class:         $b_cls"
                    echo "    Function Name: $b_func"
                    echo "    Offset:        $b_offset"
                    echo "-------------------------------------------------"
                    item_idx=$((item_idx+1))
                done < "$TMP_DIR/parsed_bookmarks.txt"
                
                echo "Options:"
                echo " • Session Memory: '1', '1,3', '1-4', 'all'"
                echo " • Delete Bookmarks: 'd1', 'd1,3', 'd1-4', 'dall'"
                echo " • Inspect Target: 'c1' (Class), 'n1' (Namespace)"
                echo " • ['m': Main Menu | '#': Go Back]"
                echo -n "Selection: "
                read bm_selection
                
                if [ "$bm_selection" = "#" ]; then break; fi
                if [ "$bm_selection" = "m" ] || [ "$bm_selection" = "M" ]; then GO_HOME=1; break; fi
                if [ -z "$bm_selection" ]; then continue; fi
                
                first_char_bm=$(echo "$bm_selection" | cut -c1 | tr '[:upper:]' '[:lower:]')

                if [ "$first_char_bm" = "n" ]; then
                    inspect_idx=$(echo "$bm_selection" | sed 's/^[nN]//')
                    if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                        if [ "$inspect_idx" -ge 1 ] && [ "$inspect_idx" -le "$TOTAL_BM" ]; then
                            raw_data=$(sed -n "${inspect_idx}p" "$TMP_DIR/parsed_bookmarks.txt")
                            inspect_ns=$(echo "$raw_data" | cut -d'|' -f3)
                            inspect_namespace_from_list "$inspect_ns"
                            if [ "$GO_HOME" -eq 1 ]; then break; fi
                        else
                            echo "❌ Invalid item number. Press [ENTER]."
                            read ignore_var
                        fi
                    else
                        echo "❌ Invalid format. Use 'n1', 'n8', etc. Press [ENTER]."
                        read ignore_var
                    fi
                    continue
                fi

                if [ "$first_char_bm" = "c" ]; then
                    inspect_idx=$(echo "$bm_selection" | sed 's/^[cC]//')
                    if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                        if [ "$inspect_idx" -ge 1 ] && [ "$inspect_idx" -le "$TOTAL_BM" ]; then
                            raw_data=$(sed -n "${inspect_idx}p" "$TMP_DIR/parsed_bookmarks.txt")
                            inspect_class=$(echo "$raw_data" | cut -d'|' -f4)
                            inspect_class_from_list "$inspect_class"
                            if [ "$GO_HOME" -eq 1 ]; then break; fi
                        else
                            echo "❌ Invalid item number. Press [ENTER]."
                            read ignore_var
                        fi
                    else
                        echo "❌ Invalid format. Use 'c1', 'c8', etc. Press [ENTER]."
                        read ignore_var
                    fi
                    continue
                fi
                
                is_delete=0
                if [ "$first_char_bm" = "d" ]; then
                    is_delete=1
                    bm_selection=$(echo "$bm_selection" | sed 's/^[dD]//')
                fi
                
                BM_IDS=""
                if [ "$bm_selection" = "all" ]; then
                    BM_IDS=$(seq 1 $TOTAL_BM)
                else
                    normalized_sel=$(echo "$bm_selection" | tr ',' ' ')
                    for item in $normalized_sel; do
                        if echo "$item" | grep -q "-"; then
                            start=${item%-*}
                            end=${item#*-}
                            if [ "$start" -eq "$start" ] 2>/dev/null && [ "$end" -eq "$end" ] 2>/dev/null; then
                                i=$start
                                while [ $i -le $end ]; do
                                    BM_IDS="$BM_IDS $i"
                                    i=$((i + 1))
                                done
                            fi
                        else
                            if [ "$item" -eq "$item" ] 2>/dev/null; then
                                BM_IDS="$BM_IDS $item"
                            fi
                        fi
                    done
                fi
                
                BM_IDS=$(echo "$BM_IDS" | xargs -n1 2>/dev/null | sort -u -n | xargs)
                if [ -z "$BM_IDS" ]; then
                    echo "❌ Invalid selection. Press [ENTER]."
                    read ignore_var
                    continue
                fi
                
                if [ "$is_delete" -eq 1 ]; then
                    > "$TMP_DIR/new_bookmarks.txt"
                    keep_idx=1
                    while IFS='|' read -r b_type b_offset b_ns b_cls b_func; do
                        delete_this=0
                        for del_id in $BM_IDS; do
                            if [ "$del_id" -eq "$keep_idx" ]; then
                                delete_this=1
                                break
                            fi
                        done
                        
                        if [ "$delete_this" -eq 0 ]; then
                            echo "Type: $b_type" >> "$TMP_DIR/new_bookmarks.txt"
                            echo "Namespace: $b_ns" >> "$TMP_DIR/new_bookmarks.txt"
                            echo "Class: $b_cls" >> "$TMP_DIR/new_bookmarks.txt"
                            echo "Function Name: $b_func" >> "$TMP_DIR/new_bookmarks.txt"
                            echo "Offset: $b_offset" >> "$TMP_DIR/new_bookmarks.txt"
                            echo "-------------------------------------------------" >> "$TMP_DIR/new_bookmarks.txt"
                        fi
                        keep_idx=$((keep_idx+1))
                    done < "$TMP_DIR/parsed_bookmarks.txt"
                    
                    cp "$TMP_DIR/new_bookmarks.txt" "$BOOKMARK_FILE"
                    echo -e "\n🗑️ Bookmarks deleted successfully!"
                    sleep 1
                else
                    for add_id in $BM_IDS; do
                        if [ "$add_id" -ge 1 ] && [ "$add_id" -le "$TOTAL_BM" ]; then
                            raw_data=$(sed -n "${add_id}p" "$TMP_DIR/parsed_bookmarks.txt")
                            type=$(echo "$raw_data" | cut -d'|' -f1)
                            offset=$(echo "$raw_data" | cut -d'|' -f2)
                            ns=$(echo "$raw_data" | cut -d'|' -f3)
                            cls=$(echo "$raw_data" | cut -d'|' -f4)
                            func=$(echo "$raw_data" | cut -d'|' -f5)
                            
                            echo "Type: $type" >> "$SESSION_TARGETS"
                            echo "Namespace: $ns" >> "$SESSION_TARGETS"
                            echo "Class: $cls" >> "$SESSION_TARGETS"
                            echo "Function Name: $func" >> "$SESSION_TARGETS"
                            echo "Offset: $offset" >> "$SESSION_TARGETS"
                            echo "-------------------------------------------------" >> "$SESSION_TARGETS"
                        fi
                    done
                    echo -e "\n✅ Added selected bookmarks to Session Memory!"
                    echo -n "Press [ENTER] to return to Main Menu..."
                    read ignore_var
                    break
                fi
            done
            continue
        fi

        # -------------------------------------------------------------
        # OPTION 1: PRECISION SEARCH
        # -------------------------------------------------------------
        if [ "$mode_choice" = "1" ]; then
            clear
            echo "================================================="
            echo "             🎯 PRECISION SEARCH                 "
            echo "================================================="
            echo "Search anything: Offset, Class, Function Name, or Namespace."
            echo "INFO: Paste exact names or offsets. Symbols like () are safe!"
            echo "-------------------------------------------------"
            echo -n "Enter your search term: "
            read prec_term

            PREC_TYPE_FILTER="ALL"
            if ! echo "$prec_term" | grep -iq "^0x"; then
                echo -e "\nFilter search by Data Type:"
                echo "1) Bool"
                echo "2) Int"
                echo "3) Float"
                echo "4) Long"
                echo "5) Void"
                echo "6) String"
                echo "7) Other"
                echo "8) 🌌 Show ALL Methods"
                echo "m) 🏠 Main Menu"
                echo -n "Choice (Default: 8): "
                read prec_type_choice
                
                if [ "$prec_type_choice" = "m" ] || [ "$prec_type_choice" = "M" ]; then continue; fi

                case $prec_type_choice in
                    1) PREC_TYPE_FILTER="Bool" ;;
                    2) PREC_TYPE_FILTER="Int" ;;
                    3) PREC_TYPE_FILTER="Float" ;;
                    4) PREC_TYPE_FILTER="Long" ;;
                    5) PREC_TYPE_FILTER="Void" ;;
                    6) PREC_TYPE_FILTER="String" ;;
                    7) PREC_TYPE_FILTER="Other" ;;
                    *) PREC_TYPE_FILTER="ALL" ;;
                esac

                echo -e "\nSelect Sorting Method:"
                echo "1) Alphabetical by Class Name (A-Z)"
                echo "2) Original Dump Order"
                echo "m) 🏠 Main Menu"
                echo -n "Choice: "
                read prec_sort_choice
                if [ "$prec_sort_choice" = "m" ] || [ "$prec_sort_choice" = "M" ]; then continue; fi
                echo -e "\nScanning dump... Please wait."
            else
                prec_sort_choice="2"
                echo -e "\nOffset detected. Searching directly..."
            fi

            > "$TMP_CUSTOM"

            if [ "$prec_sort_choice" = "1" ]; then
                awk -F'|' -v term="$(echo "$prec_term" | tr '[:upper:]' '[:lower:]')" -v type="$PREC_TYPE_FILTER" '
                    {
                        if (type == "ALL" || $1 == type) {
                            if (term == "" || index(tolower($0), term) > 0) {
                                print $0
                            }
                        }
                    }
                ' "$TMP_MASTER_CACHE" | sort -t'|' -k4,4f > "$TMP_CUSTOM"
            else
                awk -F'|' -v term="$(echo "$prec_term" | tr '[:upper:]' '[:lower:]')" -v type="$PREC_TYPE_FILTER" '
                    {
                        if (type == "ALL" || $1 == type) {
                            if (term == "" || index(tolower($0), term) > 0) {
                                print $0
                            }
                        }
                    }
                ' "$TMP_MASTER_CACHE" > "$TMP_CUSTOM"
            fi

            if [ ! -s "$TMP_CUSTOM" ]; then
                echo "❌ No targets found matching your search."
                echo -n "Press [ENTER] to return..."
                read ignore_var
                continue
            fi

            TOTAL_TARGETS=$(wc -l < "$TMP_CUSTOM" | tr -d ' ')
            START_IDX=1
            PAGE_SIZE=50

            while true; do
                END_IDX=$((START_IDX + PAGE_SIZE - 1))
                if [ "$END_IDX" -gt "$TOTAL_TARGETS" ]; then END_IDX=$TOTAL_TARGETS; fi

                clear
                echo "================================================="
                echo " PRECISION RESULTS (Showing $START_IDX to $END_IDX of $TOTAL_TARGETS)"
                echo "================================================="
                
                item_idx=$START_IDX
                sed -n "${START_IDX},${END_IDX}p" "$TMP_CUSTOM" | while IFS='|' read -r c_type c_rva c_ns c_class c_func_name; do
                    c_ns=${c_ns#Namespace: }
                    b_mark=""
                    if grep -Fxq "Offset: $c_rva" "$BOOKMARK_FILE" 2>/dev/null; then b_mark=" ⭐ [BOOKMARKED]"; fi
                    echo "[$item_idx]$b_mark"
                    echo "    Namespace:     $c_ns"
                    echo "    Class:         $c_class"
                    echo "    Function Name: $c_func_name"
                    echo "    Offset:        $c_rva"
                    echo "-------------------------------------------------"
                    item_idx=$((item_idx+1))
                done

                echo "Select Targets:"
                echo "Save to Memory: '1', '1,3', '1-4', 'all'"
                echo "Bookmark to File: 'b1', 'b1,3', 'b1-4', 'ball'"
                echo "Inspect Target: 'c1' (Class), 'n1' (Namespace)"
                if [ "$END_IDX" -lt "$TOTAL_TARGETS" ]; then
                    echo "[ENTER: Next Page | 'm': Main Menu | '#': Go Back]"
                else
                    echo "['m': Main Menu | '#': Go Back]"
                fi
                echo -n "Selection: "
                read target_selection

                if [ "$target_selection" = "#" ]; then break; fi
                if [ "$target_selection" = "m" ] || [ "$target_selection" = "M" ]; then GO_HOME=1; break; fi
                if [ -z "$target_selection" ] && [ "$END_IDX" -lt "$TOTAL_TARGETS" ]; then
                    START_IDX=$((END_IDX + 1))
                    continue
                fi

                first_char=$(echo "$target_selection" | cut -c1 | tr '[:upper:]' '[:lower:]')
                
                if [ "$first_char" = "n" ]; then
                    inspect_idx=$(echo "$target_selection" | sed 's/^[nN]//')
                    if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                        if [ "$inspect_idx" -ge "$START_IDX" ] && [ "$inspect_idx" -le "$END_IDX" ]; then
                            raw_data=$(sed -n "${inspect_idx}p" "$TMP_CUSTOM")
                            inspect_ns=$(echo "$raw_data" | cut -d'|' -f3)
                            inspect_namespace_from_list "$inspect_ns"
                            if [ "$GO_HOME" -eq 1 ]; then break; fi
                        else
                            echo "❌ Item number not on this page. Press [ENTER]."
                            read ignore_var
                        fi
                    else
                        echo "❌ Invalid format. Use 'n1', 'n8', etc. Press [ENTER]."
                        read ignore_var
                    fi
                    continue
                fi

                if [ "$first_char" = "c" ]; then
                    inspect_idx=$(echo "$target_selection" | sed 's/^[cC]//')
                    if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                        if [ "$inspect_idx" -ge "$START_IDX" ] && [ "$inspect_idx" -le "$END_IDX" ]; then
                            raw_data=$(sed -n "${inspect_idx}p" "$TMP_CUSTOM")
                            inspect_class=$(echo "$raw_data" | cut -d'|' -f4)
                            inspect_class_from_list "$inspect_class"
                            if [ "$GO_HOME" -eq 1 ]; then break; fi
                        else
                            echo "❌ Item number not on this page. Press [ENTER]."
                            read ignore_var
                        fi
                    else
                        echo "❌ Invalid format. Use 'c1', 'c8', etc. Press [ENTER]."
                        read ignore_var
                    fi
                    continue
                fi

                is_bookmark=0
                if [ "$first_char" = "b" ]; then
                    is_bookmark=1
                    target_selection=$(echo "$target_selection" | sed 's/^[bB]//')
                fi

                SELECTED_IDS=""
                if [ "$target_selection" = "all" ]; then
                    SELECTED_IDS=$(seq $START_IDX $END_IDX)
                else
                    normalized_sel=$(echo "$target_selection" | tr ',' ' ')
                    for item in $normalized_sel; do
                        if echo "$item" | grep -q "-"; then
                            start=${item%-*}
                            end=${item#*-}
                            if [ "$start" -eq "$start" ] 2>/dev/null && [ "$end" -eq "$end" ] 2>/dev/null; then
                                i=$start
                                while [ $i -le $end ]; do
                                    SELECTED_IDS="$SELECTED_IDS $i"
                                    i=$((i + 1))
                                done
                            fi
                        else
                            if [ "$item" -eq "$item" ] 2>/dev/null; then
                                SELECTED_IDS="$SELECTED_IDS $item"
                            fi
                        fi
                    done
                fi

                SELECTED_IDS=$(echo "$SELECTED_IDS" | xargs -n1 2>/dev/null | sort -u -n | xargs)

                if [ -z "$SELECTED_IDS" ]; then
                    echo "❌ No valid selection made. Press [ENTER]."
                    read ignore_var
                    continue
                fi

                for i in $SELECTED_IDS; do
                    if [ "$i" -ge 1 ] && [ "$i" -le "$TOTAL_TARGETS" ]; then
                        raw_data=$(sed -n "${i}p" "$TMP_CUSTOM")
                        type=$(echo "$raw_data" | cut -d'|' -f1)
                        rva=$(echo "$raw_data" | cut -d'|' -f2)
                        ns=$(echo "$raw_data" | cut -d'|' -f3)
                        cls=$(echo "$raw_data" | cut -d'|' -f4)
                        func_name=$(echo "$raw_data" | cut -d'|' -f5)
                        ns=${ns#Namespace: }

                        if [ "$is_bookmark" -eq 1 ]; then
                            echo "Type: $type" >> "$BOOKMARK_FILE"
                            echo "Namespace: $ns" >> "$BOOKMARK_FILE"
                            echo "Class: $cls" >> "$BOOKMARK_FILE"
                            echo "Function Name: $func_name" >> "$BOOKMARK_FILE"
                            echo "Offset: $rva" >> "$BOOKMARK_FILE"
                            echo "-------------------------------------------------" >> "$BOOKMARK_FILE"
                        else
                            echo "Type: $type" >> "$SESSION_TARGETS"
                            echo "Namespace: $ns" >> "$SESSION_TARGETS"
                            echo "Class: $cls" >> "$SESSION_TARGETS"
                            echo "Function Name: $func_name" >> "$SESSION_TARGETS"
                            echo "Offset: $rva" >> "$SESSION_TARGETS"
                            echo "-------------------------------------------------" >> "$SESSION_TARGETS"
                        fi
                    fi
                done

                if [ "$is_bookmark" -eq 1 ]; then
                    echo -e "\n⭐ Targets successfully BOOKMARKED!"
                    sleep 1
                    continue
                else
                    echo -e "\n✅ Targets successfully saved to session memory!"
                    echo -n "Press [ENTER] to return to Main Menu..."
                    read ignore_var
                    break 
                fi
            done
            if [ "$GO_HOME" -eq 1 ]; then continue; fi
        fi

        # -------------------------------------------------------------
        # OPTION E: EXPORT
        # -------------------------------------------------------------
        if [ "$mode_choice" = "E" ] || [ "$mode_choice" = "e" ]; then
            if [ "$TARGET_COUNT" -eq 0 ]; then
                echo "❌ No targets ready to export! Hunt and select some first."
                echo -n "Press [ENTER] to return..."
                read ignore_var
                continue
            fi
            EXPORT_FILE="$OUTPUT_DIR/${GAME_NAME}_ExportedTargets.txt"
            cp "$SESSION_TARGETS" "$EXPORT_FILE"
            echo "-------------------------------------------------"
            echo "✅ Successfully saved $TARGET_COUNT targets to text file!"
            echo "📂 Location: $EXPORT_FILE"
            echo -n "Press [ENTER] to return to Main Menu..."
            read ignore_var
            continue
        fi

        # -------------------------------------------------------------
        # OPTION L: GENERATE LUA
        # -------------------------------------------------------------
        if [ "$mode_choice" = "L" ] || [ "$mode_choice" = "l" ]; then
            generate_lua_script
            continue
        fi

        # -------------------------------------------------------------
        # OPTION H: HELP
        # -------------------------------------------------------------
        if [ "$mode_choice" = "H" ] || [ "$mode_choice" = "h" ]; then
            clear
            echo "================================================="
            echo "    📖 IL2CPP MASTER ENGINE - MANUAL      "
            echo "================================================="
            echo "--- TERMUX INSTALLATION & SETUP ---"
            echo "1. Grant Storage: termux-setup-storage"
            echo "2. Install Tools: pkg update && pkg install gawk findutils -y"
            echo "3. Copy Script:   cp \"/storage/emulated/0/IL2CPP Master Engine.sh\" ~/"
            echo "4. Permissions:   chmod +x ~/*/IL2CPP Master Engine.sh"
            echo "5. Run Engine:    cd ~/ && bash \"IL2CPP Master Engine.sh\""
            echo ""
            echo "--- SEARCH MODES ---"
            echo "🎯 PRECISION SEARCH: Find exact Offsets (0x...), Classes, or Methods."
            echo "🚥 CATEGORIES (2-8): Scans the dump for specific cheat types (e.g. Health)."
            echo "📂 BROWSE/FILTER: View all classes or filter all items of one type (e.g. Bool)."
            echo ""
            echo "--- HOW TO SELECT & SAVE TARGETS ---"
            echo "Lists are paginated (shows 50-200 at a time). Press [ENTER] to see the next page!"
            echo "When prompted to save, select items like this:"
            echo " • Normal Save (Session Memory): '1', '1-4', 'all'"
            echo " • Bookmark (Permanent Cache):   'b1', 'b1-4', 'ball'"
            echo " • Inspect Target:               'c1' (Class), 'n1' (Namespace)"
            echo " • Main Menu Shortcut:           'm' (Instantly returns home)"
            echo ""
            echo "--- LUA GENERATOR & BOOKMARKS ---"
            echo "Bookmarks save permanently. Use 'B' from Main Menu to load them later."
            echo "Saved session targets load into the Master Patch Dashboard. Select"
            echo "targets in batches to assign specific Hex Values before generating!"
            echo "================================================="
            echo "Press [ENTER] to go back to the menu..."
            read ignore_var
            continue
        fi

        # -------------------------------------------------------------
        # OPTION 9: BROWSE BY CLASS / FILTER BY TYPE
        # -------------------------------------------------------------
        if [ "$mode_choice" = "9" ]; then
            clear
            echo "================================================="
            echo "             📂 BROWSE & FILTER DUMP             "
            echo "================================================="
            echo -n "Enter keyword to filter (Leave blank for ALL): "
            read class_filter
            
            echo -e "\nSelect Browsing Method:"
            echo "1) Browse by Class (Alphabetical A-Z)"
            echo "2) Browse by Class (Original Dump Order) [Recommended]"
            echo "3) Filter by Data Type (Show ALL matching targets globally)"
            echo "m) 🏠 Main Menu"
            echo -n "Enter choice: "
            read sort_choice

            if [ "$sort_choice" = "m" ] || [ "$sort_choice" = "M" ]; then continue; fi

            # --- SUB-OPTION 3: GLOBAL TYPE BROWSER ---
            if [ "$sort_choice" = "3" ]; then
                echo -e "\nSelect Data Type to Filter:"
                echo "1) Bool"
                echo "2) Int"
                echo "3) Float"
                echo "4) Long"
                echo "5) Void"
                echo "6) String"
                echo "7) Other"
                echo "m) 🏠 Main Menu"
                echo -n "Choice: "
                read type_choice
                
                if [ "$type_choice" = "m" ] || [ "$type_choice" = "M" ]; then continue; fi

                TYPE_FILTER="Bool"
                case $type_choice in
                    1) TYPE_FILTER="Bool" ;;
                    2) TYPE_FILTER="Int" ;;
                    3) TYPE_FILTER="Float" ;;
                    4) TYPE_FILTER="Long" ;;
                    5) TYPE_FILTER="Void" ;;
                    6) TYPE_FILTER="String" ;;
                    7) TYPE_FILTER="Other" ;;
                esac

                echo -e "\nSelect Sorting Method for $TYPE_FILTER targets:"
                echo "1) Alphabetical by Class Name (A-Z)"
                echo "2) Original Dump Order"
                echo "m) 🏠 Main Menu"
                echo -n "Choice: "
                read type_sort_choice
                
                if [ "$type_sort_choice" = "m" ] || [ "$type_sort_choice" = "M" ]; then continue; fi

                echo -e "\nScanning dump for $TYPE_FILTER targets... Please wait."

                if [ "$type_sort_choice" = "1" ]; then
                    awk -F'|' -v filter="$(echo "$class_filter" | tr '[:upper:]' '[:lower:]')" -v type="$TYPE_FILTER" '
                        $1 == type {
                            if (filter == "" || index(tolower($0), filter) > 0) {
                                print $0
                            }
                        }
                    ' "$TMP_MASTER_CACHE" | sort -t'|' -k4,4f > "$TMP_CUSTOM"
                else
                    awk -F'|' -v filter="$(echo "$class_filter" | tr '[:upper:]' '[:lower:]')" -v type="$TYPE_FILTER" '
                        $1 == type {
                            if (filter == "" || index(tolower($0), filter) > 0) {
                                print $0
                            }
                        }
                    ' "$TMP_MASTER_CACHE" > "$TMP_CUSTOM"
                fi

                if [ ! -s "$TMP_CUSTOM" ]; then
                    echo "❌ No targets found matching that type and keyword."
                    echo -n "Press [ENTER] to return..."
                    read ignore_var
                    continue
                fi
                
                TOTAL_TARGETS=$(wc -l < "$TMP_CUSTOM" | tr -d ' ')
                START_IDX=1
                PAGE_SIZE=50

                # Pagination Loop for Global Targets
                while true; do
                    END_IDX=$((START_IDX + PAGE_SIZE - 1))
                    if [ "$END_IDX" -gt "$TOTAL_TARGETS" ]; then END_IDX=$TOTAL_TARGETS; fi

                    clear
                    echo "================================================="
                    echo " GLOBAL BROWSER: $TYPE_FILTER (Showing $START_IDX to $END_IDX of $TOTAL_TARGETS)"
                    echo "================================================="
                    
                    item_idx=$START_IDX
                    sed -n "${START_IDX},${END_IDX}p" "$TMP_CUSTOM" | while IFS='|' read -r c_type c_rva c_ns c_class c_func_name; do
                        c_ns=${c_ns#Namespace: }
                        b_mark=""
                        if grep -Fxq "Offset: $c_rva" "$BOOKMARK_FILE" 2>/dev/null; then b_mark=" ⭐ [BOOKMARKED]"; fi
                        echo "[$item_idx]$b_mark"
                        echo "    Class:         $c_class"
                        echo "    Function Name: $c_func_name"
                        echo "    Offset:        $c_rva"
                        echo "-------------------------------------------------"
                        item_idx=$((item_idx+1))
                    done

                    echo "Select Targets:"
                    echo "Save to Memory: '1', '1,3', '1-4', 'all'"
                    echo "Bookmark to File: 'b1', 'b1,3', 'b1-4', 'ball'"
                    echo "Inspect Target: 'c1' (Class), 'n1' (Namespace)"
                    if [ "$END_IDX" -lt "$TOTAL_TARGETS" ]; then
                        echo "[ENTER: Next Page | 'm': Main Menu | '#': Go Back]"
                    else
                        echo "['m': Main Menu | '#': Go Back]"
                    fi
                    echo -n "Selection: "
                    read target_selection

                    if [ "$target_selection" = "#" ]; then break; fi
                    if [ "$target_selection" = "m" ] || [ "$target_selection" = "M" ]; then GO_HOME=1; break; fi
                    if [ -z "$target_selection" ] && [ "$END_IDX" -lt "$TOTAL_TARGETS" ]; then
                        START_IDX=$((END_IDX + 1))
                        continue
                    fi

                    first_char=$(echo "$target_selection" | cut -c1 | tr '[:upper:]' '[:lower:]')
                    
                    if [ "$first_char" = "n" ]; then
                        inspect_idx=$(echo "$target_selection" | sed 's/^[nN]//')
                        if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                            if [ "$inspect_idx" -ge "$START_IDX" ] && [ "$inspect_idx" -le "$END_IDX" ]; then
                                raw_data=$(sed -n "${inspect_idx}p" "$TMP_CUSTOM")
                                inspect_ns=$(echo "$raw_data" | cut -d'|' -f3)
                                inspect_namespace_from_list "$inspect_ns"
                                if [ "$GO_HOME" -eq 1 ]; then break; fi
                            else
                                echo "❌ Item number not on this page. Press [ENTER]."
                                read ignore_var
                            fi
                        else
                            echo "❌ Invalid format. Use 'n1', 'n8', etc. Press [ENTER]."
                            read ignore_var
                        fi
                        continue
                    fi

                    if [ "$first_char" = "c" ]; then
                        inspect_idx=$(echo "$target_selection" | sed 's/^[cC]//')
                        if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                            if [ "$inspect_idx" -ge "$START_IDX" ] && [ "$inspect_idx" -le "$END_IDX" ]; then
                                raw_data=$(sed -n "${inspect_idx}p" "$TMP_CUSTOM")
                                inspect_class=$(echo "$raw_data" | cut -d'|' -f4)
                                inspect_class_from_list "$inspect_class"
                                if [ "$GO_HOME" -eq 1 ]; then break; fi
                            else
                                echo "❌ Item number not on this page. Press [ENTER]."
                                read ignore_var
                            fi
                        else
                            echo "❌ Invalid format. Use 'c1', 'c8', etc. Press [ENTER]."
                            read ignore_var
                        fi
                        continue
                    fi

                    is_bookmark=0
                    if [ "$first_char" = "b" ]; then
                        is_bookmark=1
                        target_selection=$(echo "$target_selection" | sed 's/^[bB]//')
                    fi

                    SELECTED_IDS=""
                    if [ "$target_selection" = "all" ]; then
                        SELECTED_IDS=$(seq $START_IDX $END_IDX)
                    else
                        normalized_sel=$(echo "$target_selection" | tr ',' ' ')
                        for item in $normalized_sel; do
                            if echo "$item" | grep -q "-"; then
                                start=${item%-*}
                                end=${item#*-}
                                if [ "$start" -eq "$start" ] 2>/dev/null && [ "$end" -eq "$end" ] 2>/dev/null; then
                                    i=$start
                                    while [ $i -le $end ]; do
                                        SELECTED_IDS="$SELECTED_IDS $i"
                                        i=$((i + 1))
                                    done
                                fi
                            else
                                if [ "$item" -eq "$item" ] 2>/dev/null; then
                                    SELECTED_IDS="$SELECTED_IDS $item"
                                fi
                            fi
                        done
                    fi

                    SELECTED_IDS=$(echo "$SELECTED_IDS" | xargs -n1 2>/dev/null | sort -u -n | xargs)

                    if [ -z "$SELECTED_IDS" ]; then
                        echo "❌ No valid selection made. Press [ENTER]."
                        read ignore_var
                        continue
                    fi

                    for i in $SELECTED_IDS; do
                        if [ "$i" -ge 1 ] && [ "$i" -le "$TOTAL_TARGETS" ]; then
                            raw_data=$(sed -n "${i}p" "$TMP_CUSTOM")
                            type=$(echo "$raw_data" | cut -d'|' -f1)
                            rva=$(echo "$raw_data" | cut -d'|' -f2)
                            ns=$(echo "$raw_data" | cut -d'|' -f3)
                            cls=$(echo "$raw_data" | cut -d'|' -f4)
                            func_name=$(echo "$raw_data" | cut -d'|' -f5)
                            ns=${ns#Namespace: }

                            if [ "$is_bookmark" -eq 1 ]; then
                                echo "Type: $type" >> "$BOOKMARK_FILE"
                                echo "Namespace: $ns" >> "$BOOKMARK_FILE"
                                echo "Class: $cls" >> "$BOOKMARK_FILE"
                                echo "Function Name: $func_name" >> "$BOOKMARK_FILE"
                                echo "Offset: $rva" >> "$BOOKMARK_FILE"
                                echo "-------------------------------------------------" >> "$BOOKMARK_FILE"
                            else
                                echo "Type: $type" >> "$SESSION_TARGETS"
                                echo "Namespace: $ns" >> "$SESSION_TARGETS"
                                echo "Class: $cls" >> "$SESSION_TARGETS"
                                echo "Function Name: $func_name" >> "$SESSION_TARGETS"
                                echo "Offset: $rva" >> "$SESSION_TARGETS"
                                echo "-------------------------------------------------" >> "$SESSION_TARGETS"
                            fi
                        fi
                    done

                    if [ "$is_bookmark" -eq 1 ]; then
                        echo -e "\n⭐ Targets successfully BOOKMARKED!"
                        sleep 1
                        continue
                    else
                        echo -e "\n✅ Targets successfully saved to session memory!"
                        echo -n "Press [ENTER] to return to Main Menu..."
                        read ignore_var
                        break # Safely breaks out of Option 3 and returns to Main Menu
                    fi
                done
                if [ "$GO_HOME" -eq 1 ]; then continue; fi
                continue # Skip the Class Browser logic if Option 3 was handled
            fi

            # --- IF THEY SELECTED 1 or 2 (Class Browser) ---
            if [ "$sort_choice" = "2" ]; then
                awk -F'|' -v filter="$(echo "$class_filter" | tr '[:upper:]' '[:lower:]')" '
                    {
                        if (filter == "" || index(tolower($4), filter) > 0) {
                            if (!seen[$4]++) print $4
                        }
                    }
                ' "$TMP_MASTER_CACHE" > "$TMP_CAT"
            else
                awk -F'|' -v filter="$(echo "$class_filter" | tr '[:upper:]' '[:lower:]')" '
                    {
                        if (filter == "" || index(tolower($4), filter) > 0) {
                            print $4
                        }
                    }
                ' "$TMP_MASTER_CACHE" | sort | uniq > "$TMP_CAT"
            fi
            
            if [ ! -s "$TMP_CAT" ]; then
                echo "❌ No classes found matching that keyword."
                echo -n "Press [ENTER] to return..."
                read ignore_var
                continue
            fi
            
            TOTAL_CLASSES=$(wc -l < "$TMP_CAT" | tr -d ' ')
            START_IDX=1
            PAGE_SIZE=200

            # Pagination Loop
            while true; do
                END_IDX=$((START_IDX + PAGE_SIZE - 1))
                if [ "$END_IDX" -gt "$TOTAL_CLASSES" ]; then END_IDX=$TOTAL_CLASSES; fi

                echo -e "\n\n================================================="
                echo " Matching Classes: (Showing $START_IDX to $END_IDX of $TOTAL_CLASSES)"
                echo "================================================="
                
                sed -n "${START_IDX},${END_IDX}p" "$TMP_CAT" | awk -v offset="$START_IDX" '{print "["offset+NR-1"] "$0}'

                echo "-------------------------------------------------"
                if [ "$END_IDX" -lt "$TOTAL_CLASSES" ]; then
                    echo "[ENTER: Next Page | 'm': Main Menu | '#': Go Back]"
                else
                    echo "['m': Main Menu | '#': Go Back]"
                fi
                echo -n "Selection: "
                read cls_sel

                if [ "$cls_sel" = "#" ]; then break; fi
                if [ "$cls_sel" = "m" ] || [ "$cls_sel" = "M" ]; then GO_HOME=1; break; fi
                if [ -z "$cls_sel" ] && [ "$END_IDX" -lt "$TOTAL_CLASSES" ]; then
                    START_IDX=$((END_IDX + 1))
                    continue
                elif [ -n "$cls_sel" ] && [ "$cls_sel" -eq "$cls_sel" ] 2>/dev/null; then
                    if [ "$cls_sel" -ge 1 ] && [ "$cls_sel" -le "$TOTAL_CLASSES" ]; then
                        TARGET_CLASS=$(sed -n "${cls_sel}p" "$TMP_CAT")
                        inspect_class_from_list "$TARGET_CLASS"
                        if [ "$GO_HOME" -eq 1 ]; then break; fi
                    else
                        echo "❌ Invalid number! Must be between 1 and $TOTAL_CLASSES. Press [ENTER]."
                        read ignore_var
                    fi
                else
                    echo "❌ Invalid input. Press [ENTER]."
                    read ignore_var
                fi
            done
            if [ "$GO_HOME" -eq 1 ]; then continue; fi
            continue
        fi
        # -------------------------------------------------------------

        # Handle Standard Scans (2-8)
        if [ "$mode_choice" = "2" ] || [ "$mode_choice" = "3" ] || [ "$mode_choice" = "4" ] || [ "$mode_choice" = "5" ] || [ "$mode_choice" = "6" ] || [ "$mode_choice" = "7" ] || [ "$mode_choice" = "8" ]; then

            > "$TMP_CUSTOM"
            > "$TMP_CAT"

            MODE=""

            clear 
            echo "================================================="
            case $mode_choice in
                2) 
                    MODE="STATES"
                    echo "🎯 CATEGORY: States & Bools"
                    echo "INFO: Hunts for Yes/No switches (e.g., isVIP, isDead, canShoot)."
                    ;;
                3) 
                    MODE="ECONOMY"
                    echo "🎯 CATEGORY: Economy & Stats"
                    echo "INFO: Hunts for numbers like Health, Ammo, Coins, Gems, or XP."
                    ;;
                4) 
                    MODE="FLOW"
                    echo "🎯 CATEGORY: Combat & Game Flow"
                    echo "INFO: Hunts for action triggers like TakeDamage, Reload, Spawn."
                    ;;
                5) 
                    MODE="IAP"
                    echo "🎯 CATEGORY: Monetization & IAP"
                    echo "INFO: Hunts for real-money store logic, purchases, and ads."
                    ;;
                6) 
                    MODE="NETWORK"
                    echo "🎯 CATEGORY: Network Topologies"
                    echo "INFO: Hunts for server/client sync, RPCs, and multiplayer auth."
                    ;;
                7) 
                    MODE="PHYSICS"
                    echo "🎯 CATEGORY: Physics & Movement"
                    echo "INFO: Hunts for speed, gravity, jump height, and coordinates."
                    ;;
                8) 
                    MODE="SECURITY"
                    echo "🎯 CATEGORY: Security & Anti-Cheat"
                    echo "INFO: Hunts for cheat detection, bans, encryption, and hashing."
                    ;;
            esac
            
            echo "-------------------------------------------------"
            echo -n "Press 'y' to proceed, 'm' for Main Menu, or any other key to GO BACK: "
            read confirm_proceed
            
            if [ "$confirm_proceed" = "m" ] || [ "$confirm_proceed" = "M" ]; then continue; fi
            if [ "$confirm_proceed" != "y" ] && [ "$confirm_proceed" != "Y" ]; then continue; fi

            echo -e "\nHunting targets..."
            echo "================================================="

            awk -F'|' -v mode="$MODE" '
                BEGIN { IGNORECASE=1 }
                {
                    type = $1; rva = $2; ns = $3; cls = $4; func_name = $5
                    lower_func_name = tolower(func_name)
                    match_found = 0

                    if (mode == "STATES" && type == "Bool" && index(lower_func_name, "is") > 0 || index(lower_func_name, "has") > 0 || index(lower_func_name, "can") > 0 || index(lower_func_name, "should") > 0 || index(lower_func_name, "unlocked") > 0 || index(lower_func_name, "owned") > 0 || index(lower_func_name, "active") > 0 || index(lower_func_name, "kinematic") > 0 || index(lower_func_name, "equipped") > 0 || index(lower_func_name, "enabled") > 0 || index(lower_func_name, "disabled") > 0 || index(lower_func_name, "valid") > 0 || index(lower_func_name, "isdead") > 0 || index(lower_func_name, "isalive") > 0 || index(lower_func_name, "iswalking") > 0 || index(lower_func_name, "isjumping") > 0 || index(lower_func_name, "isducking") > 0 || index(lower_func_name, "isgrounded") > 0 || index(lower_func_name, "iscrouching") > 0 || index(lower_func_name, "issprinting") > 0 || index(lower_func_name, "isstunned") > 0 || index(lower_func_name, "isreloading") > 0 || index(lower_func_name, "isinvulnerable") > 0 || index(lower_func_name, "hasauthority") > 0 || index(lower_func_name, "islocalplayer") > 0) match_found = 1
                    else if (mode == "ECONOMY" && (type == "Int" || type == "Float" || type == "Long") && index(lower_func_name, "health") > 0 || index(lower_func_name, "hp") > 0 || index(lower_func_name, "maxhealth") > 0 || index(lower_func_name, "ammo") > 0 || index(lower_func_name, "clipsize") > 0 || index(lower_func_name, "magazinesize") > 0 || index(lower_func_name, "reserve") > 0 || index(lower_func_name, "coin") > 0 || index(lower_func_name, "money") > 0 || index(lower_func_name, "cash") > 0 || index(lower_func_name, "gold") > 0 || index(lower_func_name, "gem") > 0 || index(lower_func_name, "diamond") > 0 || index(lower_func_name, "token") > 0 || index(lower_func_name, "ticket") > 0 || index(lower_func_name, "credit") > 0 || index(lower_func_name, "score") > 0 || index(lower_func_name, "highscore") > 0 || index(lower_func_name, "points") > 0 || index(lower_func_name, "price") > 0 || index(lower_func_name, "cost") > 0 || index(lower_func_name, "reward") > 0 || index(lower_func_name, "multiplier") > 0 || index(lower_func_name, "prestige") > 0 || index(lower_func_name, "xp") > 0 || index(lower_func_name, "experience") > 0 || index(lower_func_name, "mp") > 0 || index(lower_func_name, "mana") > 0 || index(lower_func_name, "sp") > 0 || index(lower_func_name, "stamina") > 0 || index(lower_func_name, "energy") > 0 || index(lower_func_name, "capacity") > 0 || index(lower_func_name, "inventory") > 0 || index(lower_func_name, "softcurrency") > 0 || index(lower_func_name, "hardcurrency") > 0 || index(lower_func_name, "armor") > 0 || index(lower_func_name, "defense") > 0 || index(lower_func_name, "attack") > 0 || index(lower_func_name, "damage") > 0 || index(lower_func_name, "critical") > 0 || index(lower_func_name, "critrate") > 0 || index(lower_func_name, "critdamage") > 0 || index(lower_func_name, "level") > 0 || index(lower_func_name, "tier") > 0 || index(lower_func_name, "rank") > 0) match_found = 1
                    else if (mode == "FLOW" && index(lower_func_name, "enterstate") > 0 || index(lower_func_name, "onenter") > 0 || index(lower_func_name, "updatestate") > 0 || index(lower_func_name, "tick") > 0 || index(lower_func_name, "exitstate") > 0 || index(lower_func_name, "onexit") > 0 || index(lower_func_name, "switchstate") > 0 || index(lower_func_name, "changestate") > 0 || index(lower_func_name, "takedamage") > 0 || index(lower_func_name, "applydamage") > 0 || index(lower_func_name, "dealdamage") > 0 || index(lower_func_name, "calculatedamage") > 0 || index(lower_func_name, "receivedamage") > 0 || index(lower_func_name, "die") > 0 || index(lower_func_name, "kill") > 0 || index(lower_func_name, "shoot") > 0 || index(lower_func_name, "fire") > 0 || index(lower_func_name, "reload") > 0 || index(lower_func_name, "applyrecoil") > 0 || index(lower_func_name, "recoverrecoil") > 0 || index(lower_func_name, "compute") > 0 || index(lower_func_name, "calculate") > 0 || index(lower_func_name, "initialize") > 0 || index(lower_func_name, "setup") > 0 || index(lower_func_name, "validate") > 0 || index(lower_func_name, "verify") > 0 || index(lower_func_name, "process") > 0 || index(lower_func_name, "execute") > 0 || index(lower_func_name, "onplayerdeath") > 0 || index(lower_func_name, "ondamagereceived") > 0 || index(lower_func_name, "heal") > 0 || index(lower_func_name, "restore") > 0 || index(lower_func_name, "revive") > 0 || index(lower_func_name, "respawn") > 0 || index(lower_func_name, "spawn") > 0 || index(lower_func_name, "destroy") > 0 || index(lower_func_name, "despawn") > 0 || index(lower_func_name, "equip") > 0 || index(lower_func_name, "unequip") > 0 || index(lower_func_name, "consume") > 0 || index(lower_func_name, "interact") > 0) match_found = 1
                    else if (mode == "IAP" && index(lower_func_name, "processpurchase") > 0 || index(lower_func_name, "restorepurchases") > 0 || index(lower_func_name, "restoretransactions") > 0 || index(lower_func_name, "onunityadsshowcomplete") > 0 || index(lower_func_name, "purchaseprocessingresult") > 0 || index(lower_func_name, "consumable") > 0 || index(lower_func_name, "nonconsumable") > 0 || index(lower_func_name, "subscription") > 0 || index(lower_func_name, "premium") > 0 || index(lower_func_name, "vip") > 0 || index(lower_func_name, "store") > 0 || index(lower_func_name, "shop") > 0 || index(lower_func_name, "catalog") > 0 || index(lower_func_name, "receipt") > 0 || index(lower_func_name, "transaction") > 0 || index(lower_func_name, "interstitial") > 0 || index(lower_func_name, "banner") > 0 || index(lower_func_name, "rewardedad") > 0) match_found = 1
                    else if (mode == "NETWORK" && index(lower_func_name, "photonview") > 0 || index(lower_func_name, "rpc") > 0 || index(lower_func_name, "rpctarget") > 0 || index(lower_func_name, "raiseevent") > 0 || index(lower_func_name, "loginwithemailaddress") > 0 || index(lower_func_name, "registerplayfabuser") > 0 || index(lower_func_name, "auth") > 0 || index(lower_func_name, "onserver") > 0 || index(lower_func_name, "onclient") > 0 || index(lower_func_name, "sync") > 0 || index(lower_func_name, "playfab") > 0 || index(lower_func_name, "cmd") > 0 || index(lower_func_name, "network") > 0 || index(lower_func_name, "server") > 0 || index(lower_func_name, "client") > 0 || index(lower_func_name, "host") > 0 || index(lower_func_name, "peer") > 0 || index(lower_func_name, "lobby") > 0 || index(lower_func_name, "match") > 0 || index(lower_func_name, "session") > 0) match_found = 1
                    else if (mode == "PHYSICS" && index(lower_func_name, "fixedupdate") > 0 || index(lower_func_name, "addforce") > 0 || index(lower_func_name, "velocity") > 0 || index(lower_func_name, "speed") > 0 || index(lower_func_name, "acceleration") > 0 || index(lower_func_name, "move") > 0 || index(lower_func_name, "simplemove") > 0 || index(lower_func_name, "stepoffset") > 0 || index(lower_func_name, "slopelimit") > 0 || index(lower_func_name, "skinwidth") > 0 || index(lower_func_name, "timescale") > 0 || index(lower_func_name, "fixeddeltatime") > 0 || index(lower_func_name, "gravity") > 0 || index(lower_func_name, "friction") > 0 || index(lower_func_name, "drag") > 0 || index(lower_func_name, "impulse") > 0 || index(lower_func_name, "torque") > 0 || index(lower_func_name, "position") > 0 || index(lower_func_name, "rotation") > 0 || index(lower_func_name, "transform") > 0) match_found = 1
                    else if (mode == "SECURITY" && index(lower_func_name, "obscuredint") > 0 || index(lower_func_name, "obscuredfloat") > 0 || index(lower_func_name, "obscuredvector3") > 0 || index(lower_func_name, "obscuredcheatingdetector") > 0 || index(lower_func_name, "randomizecryptokey") > 0 || index(lower_func_name, "cheat") > 0 || index(lower_func_name, "hack") > 0 || index(lower_func_name, "ban") > 0 || index(lower_func_name, "detect") > 0 || index(lower_func_name, "tamper") > 0 || index(lower_func_name, "emulator") > 0 || index(lower_func_name, "jailbreak") > 0 || index(lower_func_name, "root") > 0 || index(lower_func_name, "encrypt") > 0 || index(lower_func_name, "decrypt") > 0 || index(lower_func_name, "obfuscate") > 0 || index(lower_func_name, "hash") > 0 || index(lower_func_name, "checksum") > 0 || index(lower_func_name, "suspended") > 0) match_found = 1

                    if (match_found == 1) { print $0 }
                }
            ' "$TMP_MASTER_CACHE" > "$TMP_CUSTOM"

            if [ ! -s "$TMP_CUSTOM" ]; then
                echo "❌ No hits found for this category."
                echo -n "Press [ENTER] to go back..."
                read ignore_var
                continue
            fi

            # Group by Categories & Enter Sniper Mode
            while true; do
                echo -e "\n\n================================================="
                echo " Found the following Data Types:"
                echo "================================================="

                categories=$(awk -F'|' '{print $1}' "$TMP_CUSTOM" | sort | uniq)
                cat_index=1
                for cat in $categories; do
                    count=$(grep -c "^$cat|" "$TMP_CUSTOM")
                    echo "$cat_index) $cat ($count items found)"
                    eval "cat_name_$cat_index=\"$cat\""
                    cat_index=$((cat_index+1))
                done

                echo "-------------------------------------------------"
                echo -n "Select a data type number ('m' for Main Menu, '#' to go back): "
                read cat_choice

                if [ "$cat_choice" = "#" ]; then break; fi
                if [ "$cat_choice" = "m" ] || [ "$cat_choice" = "M" ]; then GO_HOME=1; break; fi

                eval "SELECTED_CAT=\$cat_name_$cat_choice"

                if [ -z "$SELECTED_CAT" ]; then
                    echo "❌ Invalid category. Press [ENTER]."
                    read ignore_var
                    continue
                fi

                grep "^$SELECTED_CAT|" "$TMP_CUSTOM" > "$TMP_CAT"
                
                TOTAL_TARGETS=$(wc -l < "$TMP_CAT" | tr -d ' ')
                START_IDX=1
                PAGE_SIZE=200

                # Pagination Loop for Categories (Options 2-8)
                while true; do
                    END_IDX=$((START_IDX + PAGE_SIZE - 1))
                    if [ "$END_IDX" -gt "$TOTAL_TARGETS" ]; then END_IDX=$TOTAL_TARGETS; fi

                    clear
                    echo "================================================="
                    echo " Showing targets for: $SELECTED_CAT (Showing $START_IDX to $END_IDX of $TOTAL_TARGETS)"
                    echo "================================================="
                    
                    item_idx=$START_IDX
                    sed -n "${START_IDX},${END_IDX}p" "$TMP_CAT" | while IFS='|' read -r c_type c_rva c_ns c_class c_func_name; do
                        c_ns=${c_ns#Namespace: }
                        b_mark=""
                        if grep -Fxq "Offset: $c_rva" "$BOOKMARK_FILE" 2>/dev/null; then b_mark=" ⭐ [BOOKMARKED]"; fi
                        echo "[$item_idx]$b_mark"
                        echo "    Namespace:     $c_ns"
                        echo "    Class:         $c_class"
                        echo "    Function Name: $c_func_name"
                        echo "    Offset:        $c_rva"
                        echo "-------------------------------------------------"
                        item_idx=$((item_idx+1))
                    done

                    echo "Select Targets:"
                    echo "Save to Memory: '1', '1,3', '1-4', 'all'"
                    echo "Bookmark to File: 'b1', 'b1,3', 'b1-4', 'ball'"
                    echo "Inspect Target: 'c1' (Class), 'n1' (Namespace)"
                    if [ "$END_IDX" -lt "$TOTAL_TARGETS" ]; then
                        echo "[ENTER: Next Page | 'm': Main Menu | '#': Go Back]"
                    else
                        echo "['m': Main Menu | '#': Go Back]"
                    fi
                    echo -n "Selection: "
                    read target_selection

                    if [ "$target_selection" = "#" ]; then break; fi
                    if [ "$target_selection" = "m" ] || [ "$target_selection" = "M" ]; then GO_HOME=1; break; fi
                    if [ -z "$target_selection" ] && [ "$END_IDX" -lt "$TOTAL_TARGETS" ]; then
                        START_IDX=$((END_IDX + 1))
                        continue
                    fi

                    first_char=$(echo "$target_selection" | cut -c1 | tr '[:upper:]' '[:lower:]')
                    
                    if [ "$first_char" = "n" ]; then
                        inspect_idx=$(echo "$target_selection" | sed 's/^[nN]//')
                        if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                            if [ "$inspect_idx" -ge "$START_IDX" ] && [ "$inspect_idx" -le "$END_IDX" ]; then
                                raw_data=$(sed -n "${inspect_idx}p" "$TMP_CAT")
                                inspect_ns=$(echo "$raw_data" | cut -d'|' -f3)
                                inspect_namespace_from_list "$inspect_ns"
                                if [ "$GO_HOME" -eq 1 ]; then break; fi
                            else
                                echo "❌ Item number not on this page. Press [ENTER]."
                                read ignore_var
                            fi
                        else
                            echo "❌ Invalid format. Use 'n1', 'n8', etc. Press [ENTER]."
                            read ignore_var
                        fi
                        continue
                    fi

                    if [ "$first_char" = "c" ]; then
                        inspect_idx=$(echo "$target_selection" | sed 's/^[cC]//')
                        if [ -n "$inspect_idx" ] && [ "$inspect_idx" -eq "$inspect_idx" ] 2>/dev/null; then
                            if [ "$inspect_idx" -ge "$START_IDX" ] && [ "$inspect_idx" -le "$END_IDX" ]; then
                                raw_data=$(sed -n "${inspect_idx}p" "$TMP_CAT")
                                inspect_class=$(echo "$raw_data" | cut -d'|' -f4)
                                inspect_class_from_list "$inspect_class"
                                if [ "$GO_HOME" -eq 1 ]; then break; fi
                            else
                                echo "❌ Item number not on this page. Press [ENTER]."
                                read ignore_var
                            fi
                        else
                            echo "❌ Invalid format. Use 'c1', 'c8', etc. Press [ENTER]."
                            read ignore_var
                        fi
                        continue
                    fi

                    is_bookmark=0
                    if [ "$first_char" = "b" ]; then
                        is_bookmark=1
                        target_selection=$(echo "$target_selection" | sed 's/^[bB]//')
                    fi

                    SELECTED_IDS=""
                    if [ "$target_selection" = "all" ]; then
                        SELECTED_IDS=$(seq $START_IDX $END_IDX)
                    else
                        normalized_sel=$(echo "$target_selection" | tr ',' ' ')
                        for item in $normalized_sel; do
                            if echo "$item" | grep -q "-"; then
                                start=${item%-*}
                                end=${item#*-}
                                if [ "$start" -eq "$start" ] 2>/dev/null && [ "$end" -eq "$end" ] 2>/dev/null; then
                                    i=$start
                                    while [ $i -le $end ]; do
                                        SELECTED_IDS="$SELECTED_IDS $i"
                                        i=$((i + 1))
                                    done
                                fi
                            else
                                if [ "$item" -eq "$item" ] 2>/dev/null; then
                                    SELECTED_IDS="$SELECTED_IDS $item"
                                fi
                            fi
                        done
                    fi

                    SELECTED_IDS=$(echo "$SELECTED_IDS" | xargs -n1 2>/dev/null | sort -u -n | xargs)

                    if [ -z "$SELECTED_IDS" ]; then
                        echo "❌ No valid selection made. Press [ENTER]."
                        read ignore_var
                        continue
                    fi

                    for i in $SELECTED_IDS; do
                        if [ "$i" -ge 1 ] && [ "$i" -le "$TOTAL_TARGETS" ]; then
                            raw_data=$(sed -n "${i}p" "$TMP_CAT")
                            type=$(echo "$raw_data" | cut -d'|' -f1)
                            rva=$(echo "$raw_data" | cut -d'|' -f2)
                            ns=$(echo "$raw_data" | cut -d'|' -f3)
                            cls=$(echo "$raw_data" | cut -d'|' -f4)
                            func_name=$(echo "$raw_data" | cut -d'|' -f5)
                            ns=${ns#Namespace: }

                            if [ "$is_bookmark" -eq 1 ]; then
                                echo "Type: $type" >> "$BOOKMARK_FILE"
                                echo "Namespace: $ns" >> "$BOOKMARK_FILE"
                                echo "Class: $cls" >> "$BOOKMARK_FILE"
                                echo "Function Name: $func_name" >> "$BOOKMARK_FILE"
                                echo "Offset: $rva" >> "$BOOKMARK_FILE"
                                echo "-------------------------------------------------" >> "$BOOKMARK_FILE"
                            else
                                echo "Type: $type" >> "$SESSION_TARGETS"
                                echo "Namespace: $ns" >> "$SESSION_TARGETS"
                                echo "Class: $cls" >> "$SESSION_TARGETS"
                                echo "Function Name: $func_name" >> "$SESSION_TARGETS"
                                echo "Offset: $rva" >> "$SESSION_TARGETS"
                                echo "-------------------------------------------------" >> "$SESSION_TARGETS"
                            fi
                        fi
                    done

                    if [ "$is_bookmark" -eq 1 ]; then
                        echo -e "\n⭐ Targets successfully BOOKMARKED!"
                        sleep 1
                        continue
                    else
                        echo -e "\n✅ Targets successfully saved to session memory!"
                        echo -n "Press [ENTER] to return to Main Menu..."
                        read ignore_var
                        break 2 # Escapes Categories and returns directly to Main Menu
                    fi
                done 
                if [ "$GO_HOME" -eq 1 ]; then break; fi
            done
            if [ "$GO_HOME" -eq 1 ]; then continue; fi
        fi

    done 
done

#! powershell
# chia2
param([string]$mode='default')
$appdir='C:\Users\chia2\AppData\Local\chia-blockchain\app-1.1.4'
# 定义系统分区一体的盘符
$syspartition='D:\'
# 定义p盘分区
$pssd='E:\'
# 所有永久存储分区
$all_volume='D:\','F:\','G:\','H:\','I:\','J:\'
# k32已完成目录
[System.Collections.Generic.List[string]]$k32ok=@('F:\','G:\','H:\','D:\')
# k33已完成目录
[System.Collections.Generic.List[string]]$k33ok=@('G:\','H:\')
# k32/33 分配内存
$k32ram=5000
$k33ram=8400
# cpu线程分配
$cputhread=3
# 一共启动多少个k32进程
$all_k32task_count=18
# 一共启动多少个k33进程
$all_k33task_count=5

$k32count=0
$k33count=0
# 16T 14901
function defalut16{
    $script:k32count=116
    $script:k33count=15
}

# 14T（系统分区所在磁盘）
function system14{
    $script:k32count=114
    $script:k33count=15
}

function get_allow_count($k1='k32'){
    # 计算当前分区可以添加多少个k32 k33
    # 统计当前分区中存在多少个k32， k33
    cd $dir;$current_count=(ls | findstr /s $k1 | Measure-Object | findstr /i count |%{$_.split()[5]})

    switch($k1){
        'k33'
        {
            $allow_count=($k33count - $current_count)
            return $allow_count
        }
        'k32'
        {
            $allow_count=($k32count - $current_count)
            return $allow_count
        }
    }
}

function get_part_task($k='32'){
    # 获取当前分区正在运行的k32 k33 任务
    $task_count=(Get-WmiObject Win32_Process | Select Name,CommandLine | findstr /C:"k $k" | findstr chia.exe | findstr $dir | measure | findstr /i count |%{$_.split()[5]})
    return $task_count
}

function deletepssd{
     Get-ChildItem -Path $pssd | Where-Object -FilterScript {((Get-Date)-($_.LastWriteTime)).days -gt 2} | Remove-Item
}

function get_task($t='32'){
    $current_task=(Get-WmiObject Win32_Process | Select Name,CommandLine | findstr /C:"k $t" | findstr chia.exe |  measure | findstr /i count |%{$_.split()[5]})
    return $current_task
}
function get_all_task{
    $current_k32_task=get_task('32')
    $current_k33_task=get_task('33')
    return ($current_k32_task -as [int])+($current_k33_task -as [int])
}

function add_task($k2='32'){
    # 添加 k32 k33 任务
    cd $appdir'\resources\app.asar.unpacked\daemon\'
    "start $k2 task to $dir .."
    switch($k2){
        '32'
        {
            Start-Process .\chia.exe -argumentlist "plots create -k $k2 -n 1 -b $k32ram -r $cputhread -u 128 -t $pssd -d $dir"
        }
        '33'
        {
            Start-Process .\chia.exe -argumentlist "plots create -k $k2 -n 1 -b $k33ram -r $cputhread -u 128 -t $pssd -d $dir"
        }
    }
}

function loop{
    $n32=0
    $n33=0
    $all_allow_k32task='null'
    $all_allow_k33task='null'
    $first=0
    "start listen task..."
    while(1){
#        if([String]::IsNullOrEmpty($loop_volume)){
#            [System.Collections.ArrayList]$loop_volume = $all_volume
#        }
        # 获取当前运行的所有k32 k33 任务
        $current_all_task=get_all_task
        “`r`n#########################################################################`r`n”
        "$(get-date) current all task is $current_all_task"
        “already success k32 disk part: $k32ok”
        “already success k33 disk part: $k33ok”
        "all disk allow k32 task is: $all_allow_k32task"
        "all disk allow k33 task is: $all_allow_k33task"
        “`r`n#########################################################################`r`n”

        if($k32ok.Count -eq $all_volume.Length -or
        $all_allow_k32task -lt $all_k32task_count -and
        $first -eq 1){
            $Script:all_k33task_count=13
            $Script:all_k32task_count=0
        }

        if($current_all_task -ge ($all_k32task_count+$all_k33task_count)){
            $n32=0
            $n33=0
        }

        # 判断k32 k33 任务总量 不足初始量，则开始执行添加任务操作
        while($current_all_task -lt ($all_k32task_count+$all_k33task_count)){
            # deletepssd
            $all_allow_k32task=0
            $all_allow_k33task=0
            foreach($dir in $all_volume){
                "`r`n---------------------------------in $dir partition now!!!!!-----------------------------------------------------`r`n"
                switch($dir){
                    $syspartition
                    {
                        system14
                    }
                    default
                    {
                        defalut16
                    }
                }
                # 判断k32 不足的情况
                $part_allow_count=get_allow_count('k32')
                "current part $dir allow k32 task count is $part_allow_count"
                $part_task_count=get_part_task('32')
                "current part $dir run k32 task is $part_task_count"
                while($part_task_count -lt ([Math]::Floor($all_k32task_count/$all_volume.Length)) -and
                $part_allow_count -gt $part_task_count -and
                !($k32ok -contains $dir)){
                    add_task('32')
                    sleep 300
                    $part_allow_count=get_allow_count('k32')
                    $part_task_count=get_part_task('32')
                }

                if($part_allow_count -lt $part_task_count){
                    if(!($k32ok -contains $dir)){
                        $Script:k32ok.Add($dir)
                    }
                }
                elseif($part_allow_count -gt $part_task_count -and
                $(get_task('32')) -lt $all_k32task_count -and
                $n32 -lt ($k32ok.Count*3)){
                    add_task('32')
                    "【notice】 k32 idle task is $($k32ok.Count*3) !!! add $n32 task already"
                    $n32++
                    sleep 300
                }

                $all_allow_k32task=$(get_allow_count('k32'))+$all_allow_k32task

                # 判断k33 不足的情况
                $part_allow_count=get_allow_count('k33')
                "current part $dir allow k33 task count is $part_allow_count"
                $part_task_count=get_part_task('33')
                "current part $dir run k33 task is $part_task_count"
                while($part_task_count -lt ([Math]::Floor($all_k33task_count/($all_volume.Length-$syspartition.Length))) -and
                $part_allow_count -gt $part_task_count -and
                !($k33ok -contains $dir)){
                    if($dir -eq $syspartition){
                        # 如果为系统一体分区，则直接跳过
                        break
                    }
                    add_task('33')
                    sleep 600
                    $part_allow_count=get_allow_count('k33')
                    $part_task_count=get_part_task('33')
                }
                if($part_allow_count -lt $part_task_count){
                    if(!($k33ok -contains $dir)){
                        $Script:k33ok.Add($dir)
                    }
                }
                elseif($part_allow_count -gt $part_task_count -and
                $(get_task('33')) -lt $all_k33task_count -and
                $n33 -lt ($k33ok.Count*[Math]::Floor($all_k33task_count/($all_volume.Length-$syspartition.Length)))){
                    add_task('33')
                    $n33++
                    "【notice】 k33 idle task is $($k33ok.Count*[Math]::Floor($all_k33task_count/($all_volume.Length-$syspartition.Length))) !!!add $n33 task already"
                    sleep 300
                }
                $all_allow_k33task=$(get_allow_count('k33'))+$all_allow_k33task
            }
            $current_all_task=get_all_task
            if($all_allow_k33task -le $all_k33task_count -and
            $all_allow_k32task -le $all_k32task_count){
                "【info】has been success all disk plots.........................."
                exit
            }
            if($first -eq 0){$first=1}
            break
        }
        sleep 1800
    }
}

function main{
    # 清理残留任务，格式化p盘
    Stop-Process -Name "chia"
    sleep 10
    # 第一次启动如果 pssd 分区不为空，则格式化
    cd $pssd;$pssd_avilable=(ls | Measure-Object | findstr /i count |%{$_.split()[5]})
    if($pssd_avilable -ne 0){
        Format-Volume -FileSystem NTFS -DriveLetter $pssd.split(':')[0]
    }

    # 启动主服务
    Start-Process $appdir'\Chia.exe'
    sleep 30

    "first run chia auto add task app.."

#    [System.Collections.ArrayList]$loop_volume = $all_volume
    loop
}

switch($mode){
    'start'
    {
        main
    }
    'listen'
    {
        loop
    }
    default
    {
        ">>>> faild method.."
        ">>>> this app suport parameter is:"
        ">>>> -mode start"
        ">>>> -mode listen"
    }
}

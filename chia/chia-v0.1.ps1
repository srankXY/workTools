#! powershell
# chia2

$appdir='C:\Users\chia2\AppData\Local\chia-blockchain\app-1.1.4'
# 定义系统分区一体的盘符
$syspartition='D:\'
# 定义p盘分区
$pssd='E:\'
# 所有永久存储分区
$all_volume='D:\','F:\','G:\','H:\','I:\','J:\'
# k32/33 分配内存
$k32ram=5000
$k33ram=8400
# cpu线程分配
$cputhread=3
# 单个磁盘并行k32的数量，k33 固定为1
$k32parallel=3

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


function pre_disk{
    # 统计当前分区中存在多少个k32， k33
    cd $dir;$current_k32=(ls | findstr /s k32 | Measure-Object | findstr /i count |%{$_.split()[5]})
    cd $dir;$current_k33=(ls | findstr /s k33 | Measure-Object | findstr /i count |%{$_.split()[5]})

    # 计算还可以添加多少个k32，k33
    $allow_k32=($k32count - $current_k32)
    $allow_k33=($k33count - $current_k33)

    # 添加任务 k32（数量不足三个的情况）
    if(1 -ge $allow_k32 -and
    $allow_k32 -lt $k32parallel)
    {
        $i=1;while($i -le $allow_k32){
            cd $appdir'\resources\app.asar.unpacked\daemon\'
            Start-Process .\chia.exe -argumentlist "plots create -k 32 -n 1 -b $k32ram -r $cputhread -u 128 -t $pssd -d $dir"
            $i++
            sleep 180
        }
    }# 添加 k32 任务（大于3个的情况）
    elseif($allow_k32 -ge $k32parallel){
        $pre_process_queue=($allow_k32 / $k32parallel) -as [int]
        $i=1;while($i -le $k32parallel){
            cd $appdir'\resources\app.asar.unpacked\daemon\'
            Start-Process .\chia.exe -argumentlist "plots create -k 32 -n $pre_process_queue -b $k32ram -r $cputhread -u 128 -t $pssd -d $dir"
            $i++
            sleep 180
        }
    }
    sleep 300
    # 添加 k33 任务
    if($dir -ne $syspartition){
        Start-Process .\chia.exe -argumentlist "plots create -k 33 -n $allow_k33 -b $k33ram -r $cputhread -u 128 -t $pssd -d $dir"
        sleep 600
    }
}

function main{
    # 清理残留任务，格式化p盘
    Stop-Process -Name "chia"
    sleep 120
    cd $pssd;$pssd_avilable=(ls | Measure-Object | findstr /i count |%{$_.split()[5]})
    if($pssd_avilable -ne 0){
        Format-Volume -FileSystem NTFS -DriveLetter $pssd.split(':')[0]
    }

    # 启动主服务
    Start-Process $appdir'\Chia.exe'
    sleep 60
    foreach($i in $all_volume){
        # 定义永久存储分区
        $dir=$i

        switch($i){
            # 判断是否为系统分区
            $syspartition
            {
                system14
                pre_disk
            }
            default
            {
                defalut16
                pre_disk
            }
        }
#        if($i -eq 'D:\'){
#            system14
#            pre_disk
#        }
#        else{
#            defalut16
#            pre_disk
#        }
    }
}
main

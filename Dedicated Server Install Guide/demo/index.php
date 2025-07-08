<?php
$demos_dir = './demos';

// 服务器端口映射
$server_ports = [
    '11291' => 'Ciallo',
    '11293' => '群友争夺起爆器',
    '11296' => '白白胖次',
    '11300' => 'STOP 0721 HERE',
    '20721' => '援卓骑士'
];

// 地图名称映射
$map_names = [
        // 死亡中心
        'c1m1_hotel' => '死亡中心M1',
        'c1m2_streets' => '死亡中心M2',
        'c1m3_mall' => '死亡中心M3',
        'c1m4_atrium' => '死亡中心M4',
        
        // 短暂时刻
        'c6m1_riverbank' => '短暂时刻M1',
        'c6m2_bedlam' => '短暂时刻M2',
        'c6m3_port' => '短暂时刻M3',
        
        // 黑色狂欢节
        'c2m1_highway' => '黑色狂欢节M1',
        'c2m2_fairgrounds' => '黑色狂欢节M2',
        'c2m3_coaster' => '黑色狂欢节M3',
        'c2m4_barns' => '黑色狂欢节M4',
        'c2m5_concert' => '黑色狂欢节M5',
        
        // 沼泽激战
        'c3m1_plankcountry' => '沼泽激战M1',
        'c3m2_swamp' => '沼泽激战M2',
        'c3m3_shantytown' => '沼泽激战M3',
        'c3m4_plantation' => '沼泽激战M4',
        
        // 暴风骤雨
        'c4m1_milltown_a' => '暴风骤雨M1',
        'c4m2_sugarmill_a' => '暴风骤雨M2',
        'c4m3_sugarmill_b' => '暴风骤雨M3',
        'c4m4_milltown_b' => '暴风骤雨M4',
        'c4m5_milltown_escape' => '暴风骤雨M5',
        
        // 教区
        'c5m1_waterfront' => '教区M1',
        'c5m2_park' => '教区M2',
        'c5m3_cemetery' => '教区M3',
        'c5m4_quarter' => '教区M4',
        'c5m5_bridge' => '教区M5',
        
        // 牺牲
        'c7m1_docks' => '牺牲M1',
        'c7m2_barge' => '牺牲M2',
        'c7m3_port' => '牺牲M3',
        
        // 毫不留情
        'c8m1_apartment' => '毫不留情M1',
        'c8m2_subway' => '毫不留情M2',
        'c8m3_sewers' => '毫不留情M3',
        'c8m4_interior' => '毫不留情M4',
        'c8m5_rooftop' => '毫不留情M5',
        
        // 坠机险途
        'c9m1_alleys' => '坠机险途M1',
        'c9m2_lots' => '坠机险途M2',
        
        // 死亡丧钟
        'c10m1_caves' => '死亡丧钟M1',
        'c10m2_drainage' => '死亡丧钟M2',
        'c10m3_ranchhouse' => '死亡丧钟M3',
        'c10m4_mainstreet' => '死亡丧钟M4',
        'c10m5_houseboat' => '死亡丧钟M5',
        
        // 寂静时分
        'c11m1_greenhouse' => '寂静时分M1',
        'c11m2_offices' => '寂静时分M2',
        'c11m3_garage' => '寂静时分M3',
        'c11m4_terminal' => '寂静时分M4',
        'c11m5_runway' => '寂静时分M5',
        
        // 血腥收获
        'c12m1_hilltop' => '血腥收获M1',
        'c12m2_traintunnel' => '血腥收获M2',
        'c12m3_bridge' => '血腥收获M3',
        'c12m4_barn' => '血腥收获M4',
        'c12m5_cornfield' => '血腥收获M5',
        
        // 刺骨寒溪
        'c13m1_alpinecreek' => '刺骨寒溪M1',
        'c13m2_southpinestream' => '刺骨寒溪M2',
        'c13m3_memorialbridge' => '刺骨寒溪M3',
        'c13m4_cutthroatcreek' => '刺骨寒溪M4',
        
        // 临死一博
        'c14m1_junkyard' => '临死一博M1',
        'c14m2_lighthouse' => '临死一博M2',

        // 喋血蜃楼
        'l4d2_diescraper1_apartment_361' => '喋血蜃楼M1',
        'l4d2_diescraper2_streets_361' => '喋血蜃楼M2',
        'l4d2_diescraper3_mid_361' => '喋血蜃楼M3',
        'l4d2_diescraper4_top_361' => '喋血蜃楼M4',
        
        // 颤栗深林
        'hf01_theforest' => '颤栗深林M1',
        'hf02_thesteeple' => '颤栗深林M2',
        'hf03_themansion' => '颤栗深林M3',
        'hf04_escape' => '颤栗深林M4',
        
        // C8改
        'nmrm1_apartment' => 'C8改M1',
        'nmrm2_subway' => 'C8改M2',
        'nmrm3_sewers' => 'C8改M3',
        'nmrm4_hospital' => 'C8改M4',
        'nmrm5_rooftop' => 'C8改M5',

        // 致命货运站
        'l4d2_ff01_woods' => '致命货运站M1',
        'l4d2_ff02_factory' => '致命货运站M2',
        'l4d2_ff03_highway' => '致命货运站M3',
        'l4d2_ff04_plant' => '致命货运站M4',
        'l4d2_ff05_station' => '致命货运站M5',

        // C4改
        'dprm1_milltown_a' => 'C4改M1',
        'dprm2_sugarmill_a' => 'C4改M2',
        'dprm3_sugarmill_b' => 'C4改M3',
        'dprm4_milltown_b' => 'C4改M4',
        'dprm5_milltown_escape' => 'C4改M5',

        // 绝境逢生
        'cwm1_intro' => '绝境逢生M1',
        'cwm2_warehouse' => '绝境逢生M2',
        'cwm3_drain' => '绝境逢生M3',
        'cwm4_building' => '绝境逢生M4',

        // 传送门
        'pt2_m1' => '传送门M1',
        'pt2_m2' => '传送门M2',
        'pt2_m3' => '传送门M3',
        'pt2_m4' => '传送门M4',
        'pt2_m5' => '传送门M5',

        // 绝命公路
        'x1m1_cliffs' => '绝命公路M1',
        'x1m2_path' => '绝命公路M2',
        'x1m3_city' => '绝命公路M3',
        'x1m4_forest' => '绝命公路M4',
        'x1m5_salvation' => '绝命公路M5',

        // 闪电突袭
        'l4d2_stadium1_apartment' => '闪电突袭M1',
        'l4d2_stadium2_riverwalk' => '闪电突袭M2',
        'l4d2_stadium3_city1' => '闪电突袭M3',
        'l4d2_stadium4_city2' => '闪电突袭M4',
        'l4d2_stadium5_stadium' => '闪电突袭M5',

        // 迂回前进
        'cdta_01detour' => '迂回前进M1',
        'cdta_02road' => '迂回前进M2',
        'cdta_03warehouse' => '迂回前进M3',
        'cdta_04onarail' => '迂回前进M4',
        'cdta_05finalroad' => '迂回前进M5',

        // C2改
        'dkr_m1_motel' => 'C2改M1',
        'dkr_m2_carnival' => 'C2改M2',
        'dkr_m3_tunneloflove' => 'C2改M3',
        'dkr_m4_ferris' => 'C2改M4',
        'dkr_m5_stadium' => 'C2改M5',

        // 黎明
        'l4d2_daybreak01_hotel' => '黎明M1',
        'l4d2_daybreak02_coastline' => '黎明M2',
        'l4d2_daybreak03_bridge' => '黎明M3',
        'l4d2_daybreak04_cruise' => '黎明M4',
        'l4d2_daybreak05_rescue' => '黎明M5',

        // 跨越边境
        'outline_m1' => '跨越边境M1',
        'outline_m2' => '跨越边境M2',
        'outline_m3' => '跨越边境M3',
        'outline_m4' => '跨越边境M4',

        // 城市17
        'l4d2_city17_01' => '城市17M1',
        'l4d2_city17_02' => '城市17M2',
        'l4d2_city17_03' => '城市17M3',
        'l4d2_city17_04' => '城市17M4',
        'l4d2_city17_05' => '城市17M5',

        // C5蔓延
        'PR1_Waterfront_F' => '教区蔓延M1',
        'PR2_Park_F' => '教区蔓延M2',
        'PR3_Highway_F' => '教区蔓延M3',
        'PR4_Quarter_F' => '教区蔓延M4',
        'PR5_Bridge_F' => '教区蔓延M5',
        
        // 黑暗教区
        'c5m1_darkwaterfront' => '黑暗教区M1',
        'c5m2_darkpark' => '黑暗教区M2',
        'c5m3_darkcemetery' => '黑暗教区M3',
        'c5m4_darkquarter' => '黑暗教区M4',
        'c5m5_darkbridge' => '黑暗教区M5',

        // 活死人
        'l4d_dbd2dc_anna_is_gone' => '活死人M1',
        'l4d_dbd2dc_the_mall' => '活死人M2',
        'l4d_dbd2dc_clean_up' => '活死人M3',
        'l4d_dbd2dc_undead_center' => '活死人M4',
        'l4d_dbd2dc_new_dawn' => '活死人M5',

        // 巴塞罗那
        'srocchurch' => '巴塞罗那M1',
        'plaza_espana' => '巴塞罗那M2',
        'maria_cristina' => '巴塞罗那M3',
        'mnac' => '巴塞罗那M4',

        // 黑C1改
        'dcr_m1_hotel' => '黑C1改M1',
        'dcr_m2_streets' => '黑C1改M2',
        'dcr_m3_mall' => '黑C1改M3',
        'dcr_m4_atrium' => '黑C1改M4',

        // 白C1改
        'DCR1_meetup_F' => '白C1改M1',
        'DCR2_TheVannha_F' => '白C1改M2',
        'DCR3_Streets_F' => '白C1改M3',
        'DCR4_Mallentrance_F' => '白C1改M4',
        'DCR5_Mall_F' => '白C1改M5',

        // 深邃恐惧症
        'deepp_m1' => '深邃恐惧症M1',
        'deepp_m2' => '深邃恐惧症M2',
        'deepp_m3' => '深邃恐惧症M3',
        'deepp_m4' => '深邃恐惧症M4',
        'deepp_m5' => '深邃恐惧症M5',

        // 我恨山2
        'l4d_ihm01_forest' => '我恨山M1',
        'l4d_ihm02_manor' => '我恨山M2',
        'l4d_ihm03_underground' => '我恨山M3',
        'l4d_ihm04_lumberyard' => '我恨山M4',
        'l4d_ihm05_lakeside' => '我恨山M5',

        // 增城
        'zc_m1' => '增城M1',
        'zc_m2' => '增城M2',
        'zc_m3' => '增城M3',
        'zc_m4' => '增城M4',
        'zc_m5' => '增城M5',

        // 死刑改
        'dsr_m1' => '死刑改M1',
        'dsr_m2' => '死刑改M2',
        'dsr_m3' => '死刑改M3',
        'dsr_m4_sv' => '死刑改M4',
        'dsr_m5' => '死刑改M5',

        // 大佛寺
        'bwm1_climb' => '大佛寺M1',
        'bwm2_city' => '大佛寺M2',
        'bwm3_forest' => '大佛寺M3',
        'bwm4_rooftops' => '大佛寺M4',
        'bwm5_bridge' => '大佛寺M5',

        // 城市航班
        'uf1_boulevard' => '城市航班M1',
        'uf2_rooftops' => '城市航班M2',
        'uf3_harbor' => '城市航班M3',
        'uf4_airfield' => '城市航班M4'
    ];

function findZipFiles($dir) {
    $files = [];
    try {
        $iterator = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($dir),
            RecursiveIteratorIterator::SELF_FIRST
        );

        foreach ($iterator as $file) {
            if ($file->isFile() && $file->getExtension() === 'zip') {
                $files[] = $file->getPathname();
            }
        }
    } catch (Exception $e) {
        error_log("Error reading directory: " . $e->getMessage());
    }
    
    return $files;
}

function parseFileName($filename) {
    global $server_ports, $map_names;
    
    if (preg_match('/Hana-(\d{8})-(\d{6})-(\d+)-([^-]+)-([R][12])-(\d+)\.zip/', $filename, $matches)) {
        $date = $matches[1];
        $time = $matches[2];
        $port = $matches[3];
        $map_code = $matches[4];
        $round = $matches[5];
        $random_num = $matches[6];
        
        // 获取友好的地图名称
        $map_name = isset($map_names[$map_code]) ? $map_names[$map_code] : $map_code;
        
        $datetime = DateTime::createFromFormat('Ymd-His', $date . '-' . $time);
        $formatted_date = $datetime ? $datetime->format('Y-m-d H:i:s') : "$date $time";
        
        $server_name = isset($server_ports[$port]) ? $server_ports[$port] : "端口 $port";
        
        return [
            'map' => $map_name,
            'map_code' => $map_code,  // 保留原始地图代码
            'round' => $round,
            'round_num' => $random_num,
            'date' => $formatted_date,
            'server' => $server_name,
            'original_name' => $filename
        ];
    }
    
    return null;
}
?>

<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hana Server DemoList</title>
    <link rel="icon" type="image/png" href="favicon.png">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0/css/all.min.css" rel="stylesheet">
    <style>
        :root {
            --primary-color: #2c3e50;
            --secondary-color: #34495e;
            --accent-color: #3498db;
        }
        
        body {
            background-color: #f8f9fa;
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        }
        
        .navbar {
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        .navbar-brand {
            font-weight: 600;
            letter-spacing: 1px;
        }

        .demo-card {
            transition: all 0.3s ease;
            border: none;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            border-radius: 12px;
            overflow: hidden;
            background: white;
        }

        .demo-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 5px 20px rgba(0,0,0,0.1);
        }

        .search-box {
            max-width: 600px;
            margin: 30px auto;
        }

        .search-box .form-control {
            border-radius: 25px;
            padding: 12px 25px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            border: none;
            font-size: 1rem;
        }

        .search-box .form-control:focus {
            box-shadow: 0 2px 15px rgba(52, 152, 219, 0.2);
        }

        .server-badge {
            position: absolute;
            top: 15px;
            right: 15px;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 500;
            letter-spacing: 0.5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }

        .card-body {
            padding: 1.5rem;
        }

        .card-title {
            font-size: 1.2rem;
            font-weight: 600;
            color: var(--primary-color);
            margin-bottom: 1rem;
            padding-top: 1.5rem;
        }

        .card-text {
            color: #666;
            line-height: 1.6;
        }

        .btn-primary {
            background: linear-gradient(135deg, var(--accent-color), #2980b9);
            border: none;
            padding: 8px 20px;
            border-radius: 20px;
            font-weight: 500;
            transition: all 0.3s ease;
        }

        .btn-primary:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(52, 152, 219, 0.3);
        }

        /* 自定义服务器颜色 */
        .server-Ciallo { background-color: #e74c3c; }
        .server-群友争夺起爆器 { background-color: #f1c40f; }
        .server-白白胖次 { background-color: #9b59b6; }
        .server-STOP-0721-HERE { background-color: #2ecc71; }
        .server-援卓骑士 { background-color: #1abc9c; }

        .footer {
            margin-top: 50px;
            padding: 20px 0;
            background: linear-gradient(135deg, var(--primary-color), var(--secondary-color));
            color: white;
            text-align: center;
        }

        @media (max-width: 768px) {
            .card-body {
                padding: 1rem;
            }
            .server-badge, .round-badge {
                font-size: 0.75em;
            }
        }
        .round-badge {
            position: absolute;
            top: 15px;
            left: 15px;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 500;
            letter-spacing: 0.5px;
        }
        .round-R1 {
            background-color: #ff69b4;  /* 粉色 */
            color: white;
        }
        .round-R2 {
            background-color: #90EE90;  /* 绿色 */
            color: white;
        }
        .card-title {
            font-size: 1.2rem;
            font-weight: 600;
            color: var(--primary-color);
            margin-bottom: 0.5rem;
            padding-top: 2rem;  /* 增加上边距，为徽章留出空间 */
        }
        .card-text {
            color: #666;
            line-height: 1.6;
        }
    </style>
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark">
        <div class="container">
            <a class="navbar-brand" href="https://www.hanacloud.site">
                <i class="fas fa-briefcase-medical me-2"></i>Hana Server DemoList
            </a>
        </div>
    </nav>

    <div class="container py-5">
        <div class="search-box">
            <input type="text" id="searchInput" class="form-control" 
                   placeholder="搜索 Demo（标识/地图/日期）..."
                   autocomplete="off">
        </div>

        <div class="row g-4" id="demoList">
            <?php
            try {
                $files = findZipFiles($demos_dir);
                
                if (empty($files)) {
                    echo '<div class="col-12 text-center">';
                    echo '<div class="alert alert-info" role="alert">';
                    echo '暂无 Demo 文件';
                    echo '</div></div>';
                } else {
                    rsort($files);

                    foreach ($files as $file) {
                        $filename = basename($file);
                        $size = round(filesize($file) / 1024 / 1024, 2);
                        $relative_path = str_replace($demos_dir . '/', '', $file);
                        
                        $info = parseFileName($filename);
                        
                        $server_class = 'server-' . str_replace([' ', '_'], '-', $info['server'] ?? 'unknown');
                        
                        $round_text = $info['round'] === 'R1' ? '上半场' : '下半场';
                        // 修改卡片显示部分
                        echo <<<HTML
                        <div class="col-md-6 col-lg-4 demo-item">
                            <div class="card demo-card position-relative">
                                <span class="server-badge badge {$server_class} text-white">
                                    {$info['server']}
                                </span>
                                <span class="round-badge round-{$info['round']}">
                                    {$round_text}
                                </span>
                                <div class="card-body">
                                    <h5 class="card-title">
                                        {$info['map']}
                                    </h5>
                                    <p class="card-text mb-2">
                                        <small class="text-muted">
                                            <i class="fas fa-map-marker-alt fa-fw me-2"></i>{$info['map_code']}<br>
                                            <i class="fas fa-star fa-fw me-2"></i>{$info['round']}-{$info['round_num']}<br>
                                            <i class="far fa-calendar-alt fa-fw me-2"></i>{$info['date']}<br>
                                            <i class="fas fa-file-archive fa-fw me-2"></i>{$size}MB
                                        </small>
                                    </p>
                                    <a href="download.php?file={$relative_path}" class="btn btn-primary w-100">
                                        <i class="fas fa-download me-2"></i>下载
                                    </a>
                                </div>
                            </div>
                        </div>
                        HTML;
                    }
                }
            } catch (Exception $e) {
                echo '<div class="col-12 text-center">';
                echo '<div class="alert alert-danger" role="alert">';
                echo '读取文件时出错：' . htmlspecialchars($e->getMessage());
                echo '</div></div>';
            }
            ?>
        </div>
    </div>

    <footer class="footer">
        <div class="container">
            <p class="mb-0">© Hana Servers | Make Hana Great Again <i class="fas fa-heart text-danger"></i></p>
        </div>
    </footer>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        const searchInput = document.getElementById('searchInput');
        const demoItems = document.querySelectorAll('.demo-item');
        let searchTimeout;

        searchInput.addEventListener('input', function() {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => {
                const search = this.value.toLowerCase();
                demoItems.forEach(item => {
                    const text = item.textContent.toLowerCase();
                    item.style.display = text.includes(search) ? '' : 'none';
                });
            }, 300);
        });

        window.addEventListener('load', function() {
            document.body.classList.add('loaded');
        });
    </script>
</body>
</html>
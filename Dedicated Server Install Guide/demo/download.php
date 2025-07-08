<?php
$demos_dir = './demos';

if (isset($_GET['file'])) {
    $relative_path = str_replace('..', '', $_GET['file']);
    $filepath = $demos_dir . '/' . $relative_path;
    
    if (file_exists($filepath) && is_file($filepath)) {
        
        preg_match('/[R][12]-\d+/', basename($filepath), $matches);
        $round_info = $matches[0] ?? 'unknown';
        
        $temp_dir = sys_get_temp_dir() . '/demo_' . uniqid();
        mkdir($temp_dir);
        
        $zip = new ZipArchive();
        if ($zip->open($filepath) === TRUE) {
            $zip->extractTo($temp_dir);
            $zip->close();
            
            $files = glob($temp_dir . '/*.dem');
            if (!empty($files)) {
                $original_dem = $files[0];
                
                $temp_zip = sys_get_temp_dir() . '/Hana_' . $round_info . '_temp.zip';
                $new_zip = new ZipArchive();
                
                if ($new_zip->open($temp_zip, ZipArchive::CREATE | ZipArchive::OVERWRITE) === TRUE) {

                    $new_zip->addFile($original_dem, "Hana_$round_info.dem");
                    $new_zip->close();
                    
                    if (file_exists($temp_zip)) {
                        header('Content-Type: application/zip');
                        header('Content-Disposition: attachment; filename="Hana_' . $round_info . '.zip"');
                        header('Content-Length: ' . filesize($temp_zip));
                        
                        readfile($temp_zip);
                        
                        unlink($temp_zip);
                        unlink($original_dem);
                        rmdir($temp_dir);
                        exit;
                    }
                }
                
                if (file_exists($temp_zip)) {
                    unlink($temp_zip);
                }
            }
        }
        
        array_map('unlink', glob("$temp_dir/*.*"));
        rmdir($temp_dir);
    }
}

header('Location: index.php');
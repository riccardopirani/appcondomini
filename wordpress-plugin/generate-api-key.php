<?php
/**
 * Generatore di Chiave API per PdG App
 * 
 * Utilizzo:
 * php generate-api-key.php
 * 
 * Output: Una stringa casuale di 64 caratteri (32 byte) perfetta per PDG_APP_API_KEY
 */

// Controlla se la funzione random_bytes è disponibile (PHP 7.0+)
if (function_exists('random_bytes')) {
    // Metodo sicuro (consigliato)
    $apiKey = bin2hex(random_bytes(32));
} else {
    // Fallback per PHP < 7.0
    $apiKey = bin2hex(openssl_random_pseudo_bytes(32));
}

echo "\n";
echo "========================================\n";
echo "  Generatore Chiave API PdG App\n";
echo "========================================\n";
echo "\n";
echo "🔑 Chiave API generata:\n\n";
echo "   " . $apiKey . "\n\n";
echo "Copia questa chiave in wp-config.php:\n\n";
echo "define('PDG_APP_API_KEY', '" . $apiKey . "');\n\n";
echo "E poi in lib/services/api_service.dart:\n\n";
echo "static const String apiKey = '" . $apiKey . "';\n\n";
echo "========================================\n\n";
?>

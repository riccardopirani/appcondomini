<?php
/**
 * Plugin Name: PdG App API (PublishPress-safe + Categories)
 * Description: API per app mobile: login + accesso ai soli post leggibili secondo PublishPress Permissions (permessi su post/categorie). Endpoint categorie "navigabile". Hardening endpoint sensibili.
 * Version: 3.2
 * Author: Portobello di Gallura
 */

if (!defined('ABSPATH')) exit;

// API key: definibile in wp-config.php per evitare di hardcodarla nel plugin.
if (!defined('PDG_APP_API_KEY')) {
    define('PDG_APP_API_KEY', 'CHANGE_ME_IN_WP_CONFIG');
}

define('PDG_APP_TOKEN_META', 'pdg_app_token_hash');
define('PDG_APP_TOKEN_EXP_META', 'pdg_app_token_expiry');
define('PDG_APP_AUTH_FAIL_TRANSIENT_PREFIX', 'pdg_app_auth_fail_');

// Quanti post per categoria "campionare" per capire se l'utente può leggere qualcosa in quella categoria
if (!defined('PDG_APP_CATEGORY_SAMPLE_POSTS')) {
    define('PDG_APP_CATEGORY_SAMPLE_POSTS', 8);
}

// Quante categorie max per risposta (evita payload enormi)
if (!defined('PDG_APP_MAX_CATEGORIES')) {
    define('PDG_APP_MAX_CATEGORIES', 300);
}

/* ---------------------------
 * Helpers: API key + token
 * --------------------------- */

function pdg_app_verify_api_key(WP_REST_Request $request) {
    // Header primario (usato dall'app)
    $api_key = (string) $request->get_header('x-pdg-api-key');
    // Fallback: alcuni proxy/CDN riscrivono gli header custom
    if (!$api_key) {
        $api_key = (string) $request->get_header('x_pdg_api_key');
    }
    if (!$api_key) {
        return new WP_Error('rest_forbidden', 'Missing API key', ['status' => 403]);
    }
    if (!hash_equals(PDG_APP_API_KEY, $api_key)) {
        return new WP_Error('rest_forbidden', 'Invalid API key', ['status' => 403]);
    }
    return true;
}

function pdg_app_get_raw_authorization_header(WP_REST_Request $request): string {
    // 1) Via WP_REST_Request (quando disponibile)
    $auth = (string) $request->get_header('authorization');
    if ($auth) return $auth;

    // 2) Via $_SERVER (molti hosting usano questa forma)
    $server_candidates = [
        'HTTP_AUTHORIZATION',
        'REDIRECT_HTTP_AUTHORIZATION',
    ];
    foreach ($server_candidates as $k) {
        if (!empty($_SERVER[$k])) {
            return (string) $_SERVER[$k];
        }
    }

    // 3) Via getallheaders()/apache_request_headers (fallback)
    $headers = [];
    if (function_exists('getallheaders')) {
        $headers = getallheaders();
    } elseif (function_exists('apache_request_headers')) {
        $headers = apache_request_headers();
    }

    if (is_array($headers)) {
        foreach ($headers as $k => $v) {
            if (strcasecmp((string)$k, 'Authorization') === 0) {
                return (string) $v;
            }
        }
    }

    return '';
}

function pdg_app_get_bearer_token(WP_REST_Request $request): string {
    // Primary: Authorization: Bearer <token>
    $auth = pdg_app_get_raw_authorization_header($request);
    if ($auth && stripos($auth, 'Bearer ') === 0) {
        return trim(substr($auth, 7));
    }

    // Fallback: header custom (non viene filtrato da molti hosting)
    $token = (string) $request->get_header('x-pdg-token');
    if ($token) return trim($token);

    // Fallback: query param (ultima spiaggia)
    $token = (string) ($request->get_param('token') ?: '');
    if ($token) return trim($token);

    return '';
}

/**
 * Ritorna WP_User oppure WP_Error
 */
function pdg_app_get_user_from_token(WP_REST_Request $request) {
    $token = pdg_app_get_bearer_token($request);
    if (!$token) {
        return new WP_Error('rest_forbidden', 'Missing token', ['status' => 401]);
    }

    $now = time();
    $token_hash = hash('sha256', $token);

    $q = new WP_User_Query([
        'meta_query' => [
            [
                'key'     => PDG_APP_TOKEN_EXP_META,
                'value'   => $now,
                'compare' => '>=',
                'type'    => 'NUMERIC',
            ],
        ],
        'fields' => ['ID'],
        'number' => 1000,
    ]);

    foreach ($q->get_results() as $u) {
        $stored_hash = (string) get_user_meta($u->ID, PDG_APP_TOKEN_META, true);
        $exp         = (int) get_user_meta($u->ID, PDG_APP_TOKEN_EXP_META, true);

        if ($exp >= $now && $stored_hash && hash_equals($stored_hash, $token_hash)) {
            return get_user_by('id', $u->ID);
        }
    }

    return new WP_Error('rest_forbidden', 'Invalid or expired token', ['status' => 401]);
}

/**
 * Imposta user corrente: fondamentale per PublishPress Permissions.
 */
function pdg_app_set_current_user(int $user_id): void {
    if ($user_id > 0) {
        wp_set_current_user($user_id);
    }
}

function pdg_app_require_auth(WP_REST_Request $request) {
    $k = pdg_app_verify_api_key($request);
    if (is_wp_error($k)) return $k;

    $u = pdg_app_get_user_from_token($request);
    if (is_wp_error($u)) return $u;

    $request->set_param('_pdg_user_id', $u->ID);
    pdg_app_set_current_user((int)$u->ID);

    return true;
}

function pdg_app_current_user_id(WP_REST_Request $request): int {
    return (int) $request->get_param('_pdg_user_id');
}

/**
 * Check permessi lettura singolo post:
 * PublishPress Permissions tipicamente influenza `read_post`.
 */
function pdg_app_user_can_read_post(int $user_id, int $post_id): bool {
    if ($user_id <= 0 || $post_id <= 0) return false;

    pdg_app_set_current_user($user_id);

    return current_user_can('read_post', $post_id);
}

/* ---------------------------
 * REST endpoints
 * --------------------------- */

add_action('rest_api_init', function () {

    register_rest_route('pdg-app/v1', '/auth', [
        'methods'  => 'POST',
        'callback' => 'pdg_app_authenticate_user',
        'permission_callback' => 'pdg_app_verify_api_key',
        'args' => [
            'username' => ['required' => true, 'type' => 'string'],
            'password' => ['required' => true, 'type' => 'string'],
        ],
    ]);

    register_rest_route('pdg-app/v1', '/posts', [
        'methods'  => 'GET',
        'callback' => 'pdg_app_get_readable_posts',
        'permission_callback' => 'pdg_app_require_auth',
    ]);

    register_rest_route('pdg-app/v1', '/posts/(?P<id>\d+)', [
        'methods'  => 'GET',
        'callback' => 'pdg_app_get_readable_single_post',
        'permission_callback' => 'pdg_app_require_auth',
    ]);

    // ✅ Categorie "navigabili": include solo categorie dove l'utente può leggere almeno 1 post
    register_rest_route('pdg-app/v1', '/categories', [
        'methods'  => 'GET',
        'callback' => 'pdg_app_get_navigable_categories',
        'permission_callback' => 'pdg_app_require_auth',
    ]);
});

/* ---------------------------
 * Auth + rate limit
 * --------------------------- */

function pdg_app_authenticate_user(WP_REST_Request $request) {
    $username = (string) $request->get_param('username');
    $password = (string) $request->get_param('password');

    $ip  = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $key = PDG_APP_AUTH_FAIL_TRANSIENT_PREFIX . md5($ip);

    $fails = (int) get_transient($key);
    if ($fails >= 10) {
        return new WP_Error('rate_limited', 'Too many attempts. Try again later.', ['status' => 429]);
    }

    $user = wp_authenticate($username, $password);
    if (is_wp_error($user)) {
        set_transient($key, $fails + 1, 15 * MINUTE_IN_SECONDS);
        return new WP_Error('invalid_credentials', 'Invalid credentials', ['status' => 401]);
    }

    delete_transient($key);

    $token = bin2hex(random_bytes(32)); // 64 chars
    $hash  = hash('sha256', $token);
    $exp   = time() + (30 * DAY_IN_SECONDS);

    update_user_meta($user->ID, PDG_APP_TOKEN_META, $hash);
    update_user_meta($user->ID, PDG_APP_TOKEN_EXP_META, $exp);

    return rest_ensure_response([
        'success' => true,
        'user' => [
            'id'           => $user->ID,
            'username'     => $user->user_login,
            'display_name' => $user->display_name,
        ],
        'token'  => $token,
        'expiry' => $exp,
    ]);
}

/* ---------------------------
 * Posts (PublishPress filtered)
 * --------------------------- */

function pdg_app_get_readable_posts(WP_REST_Request $request) {
    $user_id = pdg_app_current_user_id($request);
    pdg_app_set_current_user($user_id);

    $per_page = (int) ($request->get_param('per_page') ?: 20);
    if ($per_page < 1) $per_page = 20;
    if ($per_page > 50) $per_page = 50;

    $page = (int) ($request->get_param('page') ?: 1);
    if ($page < 1) $page = 1;

    $allowed_orderby = ['date', 'modified', 'title'];
    $orderby = (string) ($request->get_param('orderby') ?: 'date');
    if (!in_array($orderby, $allowed_orderby, true)) $orderby = 'date';

    $order = strtoupper((string) ($request->get_param('order') ?: 'DESC'));
    if (!in_array($order, ['ASC', 'DESC'], true)) $order = 'DESC';

    $cat = (int) ($request->get_param('category') ?: 0);

    $args = [
        'post_type'      => 'post',
        'post_status'    => ['publish', 'private'],
        'posts_per_page' => $per_page * 6,  // oversampling
        'paged'          => $page,
        'orderby'        => $orderby,
        'order'          => $order,
        'no_found_rows'  => false,
        'ignore_sticky_posts' => true,
    ];

    if ($cat > 0) {
        $args['cat'] = $cat;
    }

    $query = new WP_Query($args);

    $posts = [];

    foreach (($query->posts ?: []) as $p) {
        if (count($posts) >= $per_page) break;

        // Normalizza WP_Post o ID
        $post_obj = null;
        $post_id  = 0;

        if (is_object($p) && isset($p->ID)) {
            $post_obj = $p;
            $post_id  = (int) $p->ID;
        } else {
            $post_id  = (int) $p;
            $post_obj = get_post($post_id);
        }

        if (!$post_obj instanceof WP_Post) continue;
        if ($post_obj->post_type !== 'post') continue;
        if (!in_array($post_obj->post_status, ['publish', 'private'], true)) continue;

        if (pdg_app_user_can_read_post($user_id, $post_id)) {
            $formatted = pdg_app_format_post($post_obj);
            if (!empty($formatted)) {
                $posts[] = $formatted;
            }
        }
    }

    return rest_ensure_response([
        'posts'        => $posts,
        'current_page' => $page,
        'note'         => 'Total/pages are approximate due to permission filtering',
    ]);
}

function pdg_app_get_readable_single_post(WP_REST_Request $request) {
    $user_id = pdg_app_current_user_id($request);
    pdg_app_set_current_user($user_id);

    $post_id = (int) $request->get_param('id');
    $post = get_post($post_id);

    if (!$post || !$post instanceof WP_Post || $post->post_type !== 'post') {
        return new WP_Error('post_not_found', 'Post not found', ['status' => 404]);
    }

    if (!in_array($post->post_status, ['publish', 'private'], true)) {
        return new WP_Error('rest_forbidden', 'Forbidden', ['status' => 403]);
    }

    if (!pdg_app_user_can_read_post($user_id, $post_id)) {
        return new WP_Error('rest_forbidden', 'Forbidden', ['status' => 403]);
    }

    return rest_ensure_response(pdg_app_format_post($post));
}

/* ---------------------------
 * Categories "navigabili"
 * --------------------------- */

function pdg_app_get_navigable_categories(WP_REST_Request $request) {
    $user_id = pdg_app_current_user_id($request);
    pdg_app_set_current_user($user_id);

    $cats = get_categories([
        'taxonomy'   => 'category',
        'hide_empty' => false,     // vogliamo anche categorie vuote (ma poi filtriamo per leggibilità)
        'number'     => PDG_APP_MAX_CATEGORIES,
        'orderby'    => 'name',
        'order'      => 'ASC',
    ]);

    $out = [];

    foreach (($cats ?: []) as $cat) {
        $cat_id = (int) $cat->term_id;
        if ($cat_id <= 0) continue;

        // Se la categoria ha zero post, NON possiamo dedurre permesso "reale".
        // Per sicurezza: la includiamo SOLO se l'app chiede esplicitamente include_empty=1 E l'utente può almeno leggere qualcosa nel sito.
        // (Default: la nascondiamo per non leakare struttura.)
        if ((int)$cat->count === 0) {
            $include_empty = (int) ($request->get_param('include_empty') ?: 0);
            if ($include_empty !== 1) {
                continue;
            }
            // include_empty=1: includiamo ma marcando readable=false (l'app può mostrarla "grigia")
            $out[] = [
                'id'     => $cat_id,
                'name'   => (string) $cat->name,
                'slug'   => (string) $cat->slug,
                'parent' => (int) $cat->parent,
                'readable' => false,
            ];
            continue;
        }

        // Campioniamo alcuni post della categoria e vediamo se ALMENO UNO è leggibile
        $sample = new WP_Query([
            'post_type'      => 'post',
            'post_status'    => ['publish', 'private'],
            'posts_per_page' => PDG_APP_CATEGORY_SAMPLE_POSTS,
            'fields'         => 'ids',
            'no_found_rows'  => true,
            'cat'            => $cat_id,
            'ignore_sticky_posts' => true,
        ]);

        $readable = false;
        foreach (($sample->posts ?: []) as $pid) {
            $pid = (int)$pid;
            if ($pid > 0 && pdg_app_user_can_read_post($user_id, $pid)) {
                $readable = true;
                break;
            }
        }

        if ($readable) {
            $out[] = [
                'id'     => $cat_id,
                'name'   => (string) $cat->name,
                'slug'   => (string) $cat->slug,
                'parent' => (int) $cat->parent,
                'readable' => true,
            ];
        }
    }

    return rest_ensure_response($out);
}

/* ---------------------------
 * Output post (minimo e robusto)
 * --------------------------- */

function pdg_app_format_post($post): array {
    if (is_numeric($post)) {
        $post = get_post((int)$post);
    }
    if (!$post instanceof WP_Post) {
        return [];
    }

    $featured_image = '';
    if (has_post_thumbnail($post->ID)) {
        $featured_image = (string) get_the_post_thumbnail_url($post->ID, 'full');
    }

    // 🔥 Estrai categorie dal post
    $categories = [];
    $post_categories = get_the_category($post->ID);
    if (!empty($post_categories) && !is_wp_error($post_categories)) {
        foreach ($post_categories as $cat) {
            $categories[] = (int) $cat->term_id;
        }
    }

    return [
        'id'       => (int) $post->ID,
        'date'     => (string) $post->post_date,
        'modified' => (string) $post->post_modified,
        'slug'     => (string) $post->post_name,
        'status'   => (string) $post->post_status,
        'link'     => (string) get_permalink($post->ID),
        'title'    => ['rendered' => (string) $post->post_title],
        'content'  => ['rendered' => apply_filters('the_content', $post->post_content)],
        'excerpt'  => ['rendered' => (string) ($post->post_excerpt ?: wp_strip_all_tags(wp_trim_words($post->post_content, 55)))],
        'featured_image_url' => $featured_image,
        'categories' => $categories, // 🔥 NUOVO: ID delle categorie
    ];
}

/* ---------------------------
 * Hardening REST: blocca endpoint sensibili
 * --------------------------- */

add_filter('rest_authentication_errors', function ($result) {
    if (!empty($result)) return $result;

    $uri = $_SERVER['REQUEST_URI'] ?? '';

    $blocked_for_non_admin = [
        '#/wp-json/wp/v2/users#',
        '#/wp-json/wp/v2/settings#',
        '#/wp-json/wp/v2/plugins#',
        '#/wp-json/wp/v2/themes#',
    ];

    foreach ($blocked_for_non_admin as $pattern) {
        if (preg_match($pattern, $uri)) {
            if (!current_user_can('manage_options')) {
                return new WP_Error('rest_forbidden', 'Forbidden', ['status' => 403]);
            }
        }
    }

    return $result;
}, 20);
?>

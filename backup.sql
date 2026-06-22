-- MySQL dump 10.13  Distrib 9.6.0, for macos26.2 (arm64)
--
-- Host: localhost    Database: real_db
-- ------------------------------------------------------
-- Server version	9.6.0

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `cache`
--

DROP TABLE IF EXISTS `cache`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cache` (
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `value` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration` bigint NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cache`
--

LOCK TABLES `cache` WRITE;
/*!40000 ALTER TABLE `cache` DISABLE KEYS */;
/*!40000 ALTER TABLE `cache` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `cache_locks`
--

DROP TABLE IF EXISTS `cache_locks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cache_locks` (
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration` bigint NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_locks_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cache_locks`
--

LOCK TABLES `cache_locks` WRITE;
/*!40000 ALTER TABLE `cache_locks` DISABLE KEYS */;
/*!40000 ALTER TABLE `cache_locks` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `failed_jobs`
--

DROP TABLE IF EXISTS `failed_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `failed_jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `connection` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `queue` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `exception` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`),
  KEY `failed_jobs_connection_queue_failed_at_index` (`connection`,`queue`,`failed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `failed_jobs`
--

LOCK TABLES `failed_jobs` WRITE;
/*!40000 ALTER TABLE `failed_jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `failed_jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `group_user`
--

DROP TABLE IF EXISTS `group_user`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `group_user` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `group_id` bigint unsigned NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `group_user_user_id_foreign` (`user_id`),
  KEY `group_user_group_id_foreign` (`group_id`),
  CONSTRAINT `group_user_group_id_foreign` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_user_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `group_user`
--

LOCK TABLES `group_user` WRITE;
/*!40000 ALTER TABLE `group_user` DISABLE KEYS */;
INSERT INTO `group_user` VALUES (1,1,1,NULL,NULL),(3,6,2,NULL,NULL),(4,7,2,NULL,NULL),(6,7,3,NULL,NULL),(7,3,1,NULL,NULL),(8,4,1,NULL,NULL),(9,1,2,NULL,NULL),(10,4,2,NULL,NULL);
/*!40000 ALTER TABLE `group_user` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `groups`
--

DROP TABLE IF EXISTS `groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `groups` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `display_name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `groups_name_unique` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `groups`
--

LOCK TABLES `groups` WRITE;
/*!40000 ALTER TABLE `groups` DISABLE KEYS */;
INSERT INTO `groups` VALUES (1,'VIP','VIP',NULL,NULL),(2,'security','ក្រុមសន្តិសុខទូទៅ','2026-06-17 07:29:32','2026-06-17 07:29:32'),(3,'control_room','បន្ទប់បញ្ជាការ','2026-06-17 07:29:32','2026-06-17 07:29:32');
/*!40000 ALTER TABLE `groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `job_batches`
--

DROP TABLE IF EXISTS `job_batches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `job_batches` (
  `id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_jobs` int NOT NULL,
  `pending_jobs` int NOT NULL,
  `failed_jobs` int NOT NULL,
  `failed_job_ids` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `options` mediumtext COLLATE utf8mb4_unicode_ci,
  `cancelled_at` int DEFAULT NULL,
  `created_at` int NOT NULL,
  `finished_at` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `job_batches`
--

LOCK TABLES `job_batches` WRITE;
/*!40000 ALTER TABLE `job_batches` DISABLE KEYS */;
/*!40000 ALTER TABLE `job_batches` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `jobs`
--

DROP TABLE IF EXISTS `jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `queue` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `attempts` smallint unsigned NOT NULL,
  `reserved_at` int unsigned DEFAULT NULL,
  `available_at` int unsigned NOT NULL,
  `created_at` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `jobs_queue_index` (`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `jobs`
--

LOCK TABLES `jobs` WRITE;
/*!40000 ALTER TABLE `jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `jobs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `migrations`
--

DROP TABLE IF EXISTS `migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `migrations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `migrations`
--

LOCK TABLES `migrations` WRITE;
/*!40000 ALTER TABLE `migrations` DISABLE KEYS */;
INSERT INTO `migrations` VALUES (1,'0001_01_01_000000_create_users_table',1),(2,'0001_01_01_000001_create_cache_table',1),(3,'0001_01_01_000002_create_jobs_table',1),(4,'2026_06_16_045029_create_personal_access_tokens_table',1),(6,'2026_06_17_133633_create_groups_table',2),(7,'2026_06_17_133634_create_group_user_table',2);
/*!40000 ALTER TABLE `migrations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `password_reset_tokens`
--

DROP TABLE IF EXISTS `password_reset_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `password_reset_tokens` (
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `password_reset_tokens`
--

LOCK TABLES `password_reset_tokens` WRITE;
/*!40000 ALTER TABLE `password_reset_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `password_reset_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `personal_access_tokens`
--

DROP TABLE IF EXISTS `personal_access_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `personal_access_tokens` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `tokenable_type` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `tokenable_id` bigint unsigned NOT NULL,
  `name` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `abilities` text COLLATE utf8mb4_unicode_ci,
  `last_used_at` timestamp NULL DEFAULT NULL,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `personal_access_tokens_token_unique` (`token`),
  KEY `personal_access_tokens_tokenable_type_tokenable_id_index` (`tokenable_type`,`tokenable_id`),
  KEY `personal_access_tokens_expires_at_index` (`expires_at`)
) ENGINE=InnoDB AUTO_INCREMENT=66 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `personal_access_tokens`
--

LOCK TABLES `personal_access_tokens` WRITE;
/*!40000 ALTER TABLE `personal_access_tokens` DISABLE KEYS */;
INSERT INTO `personal_access_tokens` VALUES (1,'App\\Models\\User',1,'WebDashboard','c0953f062dfd613ed3d8f08c1f2f47aa135e3f205601196961c34e3115707bb3','[\"*\"]','2026-06-15 23:19:48',NULL,'2026-06-15 22:56:30','2026-06-15 23:19:48'),(2,'App\\Models\\User',1,'WebDashboard','488ba293a50639579a0c648039f162ddbc71020034e08f8b52e4a716e851b5d5','[\"*\"]',NULL,NULL,'2026-06-15 23:19:48','2026-06-15 23:19:48'),(3,'App\\Models\\User',1,'WebDashboard','c46015c9265e2ef0cbc6bb7d5cd631a9dc2865c1ac9adf77c6230dcc68a0f964','[\"*\"]','2026-06-15 23:34:42',NULL,'2026-06-15 23:33:36','2026-06-15 23:34:42'),(4,'App\\Models\\User',1,'WebDashboard','f8f5401c35a3211e8b2756c2de079e653c5ae7c80d35ad094932537fac653367','[\"*\"]','2026-06-15 23:39:36',NULL,'2026-06-15 23:34:45','2026-06-15 23:39:36'),(5,'App\\Models\\User',3,'WebDashboard','0af543c026117b90d64d6557b0b8b3c3c589050f7848671cde6630604b1611c1','[\"*\"]','2026-06-15 23:52:31',NULL,'2026-06-15 23:39:52','2026-06-15 23:52:31'),(6,'App\\Models\\User',1,'WebDashboard','8a59c2af678fe78dbf76055ae3fe89cb884e42ceeef2ac17de6670fad1c7b9be','[\"*\"]','2026-06-15 23:49:20',NULL,'2026-06-15 23:49:20','2026-06-15 23:49:20'),(7,'App\\Models\\User',1,'WebDashboard','52bbb41d67ff1ae0a0e6d7db1ee797fa53539bb212ca7f9cb82123ba9b0e0a55','[\"*\"]','2026-06-15 23:52:31',NULL,'2026-06-15 23:49:47','2026-06-15 23:52:31'),(8,'App\\Models\\User',1,'WebDashboard','8a1d5b464be617bc9f9c9ce907984b094f3f87863eee97643301e85efcc6ff4b','[\"*\"]','2026-06-15 23:59:12',NULL,'2026-06-15 23:54:41','2026-06-15 23:59:12'),(9,'App\\Models\\User',3,'WebDashboard','c6419b5da7f1ca2f0c1159b8936e2cb8a75a3990cd7645789dc8c08c97f2ccdb','[\"*\"]','2026-06-15 23:58:31',NULL,'2026-06-15 23:55:08','2026-06-15 23:58:31'),(10,'App\\Models\\User',1,'WebDashboard','1f5f406ad334c8184c75c5c93d8572185db996e961a15681ac18471bb223109f','[\"*\"]','2026-06-16 00:24:57',NULL,'2026-06-16 00:12:56','2026-06-16 00:24:57'),(11,'App\\Models\\User',3,'WebDashboard','996163d53806f72a3c8be6fbf2d1465ed8885be26001115cd70f874ff66a3784','[\"*\"]','2026-06-16 00:24:47',NULL,'2026-06-16 00:14:37','2026-06-16 00:24:47'),(12,'App\\Models\\User',1,'WebDashboard','dec7624f29661002b57170119813fda911bb1becc6c91d21901bdbdeea04007f','[\"*\"]','2026-06-16 02:27:12',NULL,'2026-06-16 00:25:02','2026-06-16 02:27:12'),(13,'App\\Models\\User',3,'WebDashboard','912e3188673fecdb19e7eccc269f7b3cfb51d5947c929b631f193987364788e3','[\"*\"]','2026-06-16 01:22:32',NULL,'2026-06-16 00:25:18','2026-06-16 01:22:32'),(14,'App\\Models\\User',3,'WebDashboard','21bb1dc5528c525051ae91d70ef654d950d8f1bc91fdd8851b13b8fafcf5e7c4','[\"*\"]','2026-06-16 03:10:36',NULL,'2026-06-16 00:27:42','2026-06-16 03:10:36'),(15,'App\\Models\\User',3,'WebDashboard','d4bebb8d31bba819aecc678fcb623cb80c2b97222376285d2a0239ca0ad2e8f9','[\"*\"]','2026-06-16 02:38:32',NULL,'2026-06-16 02:18:03','2026-06-16 02:38:32'),(16,'App\\Models\\User',1,'WebDashboard','92105338805764c94ce03fbdb2b8ee6b147a0b77251e52ae7cb1eb025fbc06fe','[\"*\"]','2026-06-16 02:28:07',NULL,'2026-06-16 02:28:07','2026-06-16 02:28:07'),(17,'App\\Models\\User',1,'WebDashboard','cba97da5e898249a3c560e116f4a718d4c2af3bc0c2863777cfb4d38ed12665c','[\"*\"]','2026-06-16 02:28:51',NULL,'2026-06-16 02:28:51','2026-06-16 02:28:51'),(18,'App\\Models\\User',1,'WebDashboard','adf4ada738c33a9568834c93fbd528edcb5e01d97e9861de5f07059509b6e84f','[\"*\"]',NULL,NULL,'2026-06-16 02:56:29','2026-06-16 02:56:29'),(19,'App\\Models\\User',1,'WebDashboard','92f004af1e2a735ac5a0c3473603764067a4e410005fad6a0bb0d324d21ef877','[\"*\"]','2026-06-16 02:57:16',NULL,'2026-06-16 02:57:16','2026-06-16 02:57:16'),(20,'App\\Models\\User',3,'WebDashboard','56a690145de2cdc3f3dfbf40ca1b26f66a5295035105d91840b592fc057804d5','[\"*\"]','2026-06-16 03:02:34',NULL,'2026-06-16 02:57:44','2026-06-16 03:02:34'),(21,'App\\Models\\User',1,'WebDashboard','c1236d434a6c11405181767f646728e89176cd2dd6a4b6fffa661f6c7b203a55','[\"*\"]','2026-06-16 03:02:48',NULL,'2026-06-16 02:59:23','2026-06-16 03:02:48'),(22,'App\\Models\\User',1,'WebDashboard','4d3f1591d2a9f2b9976fbf91031b85de5da57f324131509a89966191503f629d','[\"*\"]','2026-06-16 03:07:48',NULL,'2026-06-16 03:07:48','2026-06-16 03:07:48'),(23,'App\\Models\\User',1,'WebDashboard','854eb6a7fbda3d6ad32eb7ad656d67ed5d05ba2642d3fe21b4cf94f26c4cf2f3','[\"*\"]','2026-06-16 03:08:53',NULL,'2026-06-16 03:08:07','2026-06-16 03:08:53'),(24,'App\\Models\\User',1,'WebDashboard','5956ab645a5a1e9f1abb629ba3b5bb79606b67cf642de9716ff068d3971ec55e','[\"*\"]','2026-06-16 03:09:00',NULL,'2026-06-16 03:09:00','2026-06-16 03:09:00'),(25,'App\\Models\\User',3,'WebDashboard','fe64b5bc125cc6a1a6408082f6bb35dd29a6e969607a61e749b124dac175f4f5','[\"*\"]','2026-06-16 03:29:50',NULL,'2026-06-16 03:09:11','2026-06-16 03:29:50'),(26,'App\\Models\\User',1,'WebDashboard','f6432287f90f937a56ba08dfe6c7aa0141e34c1def4bfa4b7b1daf81d476a074','[\"*\"]','2026-06-16 03:12:21',NULL,'2026-06-16 03:11:14','2026-06-16 03:12:21'),(27,'App\\Models\\User',3,'WebDashboard','50e41f94a4b42f277e80b47f870cb763defd1820ddf00dd0d146f96a9c2ad788','[\"*\"]','2026-06-16 03:49:07',NULL,'2026-06-16 03:13:14','2026-06-16 03:49:07'),(28,'App\\Models\\User',1,'WebDashboard','06c8d0162249beb1cc42ba1ef2bf5d2d5bd10536b9f91bbb85f87cbf2a8da48a','[\"*\"]','2026-06-16 03:19:20',NULL,'2026-06-16 03:13:40','2026-06-16 03:19:20'),(29,'App\\Models\\User',1,'WebDashboard','6999e50ce9e82cf24dceed80cbcdff86031b55b168fdb0264cf9baf8fd900fee','[\"*\"]','2026-06-16 03:33:08',NULL,'2026-06-16 03:32:07','2026-06-16 03:33:08'),(30,'App\\Models\\User',1,'WebDashboard','23b3365ea60a8a5c7b9af9eafd3fecffb510c73056b7953d27aeceb069d85a5d','[\"*\"]','2026-06-16 03:51:55',NULL,'2026-06-16 03:33:50','2026-06-16 03:51:55'),(31,'App\\Models\\User',3,'WebDashboard','dbfa28cc52c0b2c23082baed705d3b845c1322924f643dbce99ccc0d9878417e','[\"*\"]','2026-06-16 03:38:09',NULL,'2026-06-16 03:34:12','2026-06-16 03:38:09'),(32,'App\\Models\\User',1,'WebDashboard','0659b5598ca59df9e7e5872f43a5bf7f1ba1e39e30fa2c322fe29be1d13ed1b3','[\"*\"]','2026-06-16 03:52:44',NULL,'2026-06-16 03:51:58','2026-06-16 03:52:44'),(33,'App\\Models\\User',1,'WebDashboard','0cec81eb80740515ce03951e66a88ffdb5e2b4d9ebe1ccd2ebfa1894b3d59b33','[\"*\"]','2026-06-16 05:18:22',NULL,'2026-06-16 05:18:22','2026-06-16 05:18:22'),(34,'App\\Models\\User',3,'WebDashboard','3047bbe2dc9cafe29351776a8862e20201d6573892b8987c85cd62261c201c0d','[\"*\"]','2026-06-16 05:41:16',NULL,'2026-06-16 05:35:24','2026-06-16 05:41:16'),(35,'App\\Models\\User',1,'WebDashboard','21154f5b776243f7eaf689975165e7b7a4394734ea856fd78b90ad0393a64dcf','[\"*\"]','2026-06-16 05:47:59',NULL,'2026-06-16 05:36:10','2026-06-16 05:47:59'),(36,'App\\Models\\User',3,'WebDashboard','a317cebc7b994975b110f8f2979bbfd635ef767577b621cf6304e146c20c974f','[\"*\"]','2026-06-16 05:58:12',NULL,'2026-06-16 05:42:28','2026-06-16 05:58:12'),(37,'App\\Models\\User',1,'WebDashboard','afa7215eb7f9cbdfbd0316a0c5936703508b0d0e9f53476caeaa4d03a2d1674c','[\"*\"]','2026-06-16 05:57:09',NULL,'2026-06-16 05:48:10','2026-06-16 05:57:09'),(38,'App\\Models\\User',1,'WebDashboard','65cf4fa79752e0bcd19926f093b2a887beddd76e5704f1bd1d1e7e86a8653728','[\"*\"]','2026-06-16 06:16:02',NULL,'2026-06-16 05:58:51','2026-06-16 06:16:02'),(39,'App\\Models\\User',3,'WebDashboard','cfd3c9b44be1ea8bbb3d2d8910180dc54d5b1c0e56bcccd32aa96a28ad96cf1c','[\"*\"]','2026-06-16 06:16:21',NULL,'2026-06-16 05:59:23','2026-06-16 06:16:21'),(40,'App\\Models\\User',1,'WebDashboard','f1336234e810b6fcf668b6b143cfc405f97e980c86bcc5bcd0c45fd6dd450fad','[\"*\"]','2026-06-16 07:21:19',NULL,'2026-06-16 06:16:32','2026-06-16 07:21:19'),(41,'App\\Models\\User',3,'WebDashboard','f51ecf1c14d8ea0510fe9b8d27a6585ba30702716844481146e7fa9a6c8b6818','[\"*\"]','2026-06-17 07:10:47',NULL,'2026-06-16 06:16:42','2026-06-17 07:10:47'),(42,'App\\Models\\User',4,'WebDashboard','ec84cc1bc08fe3f8f743df68b81267a2468401171901f87db332493c9ace196e','[\"*\"]','2026-06-16 06:26:03',NULL,'2026-06-16 06:26:03','2026-06-16 06:26:03'),(43,'App\\Models\\User',4,'WebDashboard','b59e78f944bc750e48cd31c176fbf9ff9e2b8584d29e0cb26226341945c2637b','[\"*\"]','2026-06-16 07:02:56',NULL,'2026-06-16 06:29:18','2026-06-16 07:02:56'),(44,'App\\Models\\User',4,'WebDashboard','493abbb56100082b14ff17e24fc5ba7e618ac2929c8eff76d7fc6424bd730a77','[\"*\"]','2026-06-16 07:22:28',NULL,'2026-06-16 07:03:42','2026-06-16 07:22:28'),(45,'App\\Models\\User',1,'WebDashboard','5cb23e6cfc764fc1c3fd33e115760af45ae8b8c1d2f4bbb0acb1cd3b0d3fe72f','[\"*\"]','2026-06-16 07:25:40',NULL,'2026-06-16 07:25:40','2026-06-16 07:25:40'),(46,'App\\Models\\User',4,'WebDashboard','15e3a8bf839663aaa09a3ef342ae461163627deb540aebd3a51a2529161cd5c4','[\"*\"]',NULL,NULL,'2026-06-16 07:28:44','2026-06-16 07:28:44'),(47,'App\\Models\\User',1,'WebDashboard','f3927b0b786c0d67dc826b63349db0aff68fc4db73c154a28f576b95a5795a2b','[\"*\"]',NULL,NULL,'2026-06-16 07:28:55','2026-06-16 07:28:55'),(48,'App\\Models\\User',4,'WebDashboard','17ea62847fbf7e0067796d7955b0fbe7139f773822cf6f90a3f1742553560fdb','[\"*\"]','2026-06-17 06:18:33',NULL,'2026-06-17 06:04:04','2026-06-17 06:18:33'),(49,'App\\Models\\User',4,'WebDashboard','e12424c9cd7cd832dfdda1713b80baa43334018235c3b3c86ffccca39c4cb456','[\"*\"]','2026-06-17 06:24:04',NULL,'2026-06-17 06:24:04','2026-06-17 06:24:04'),(50,'App\\Models\\User',4,'WebDashboard','abcae38a9af394536dd5202896b1af6a40a840f8e5880b8a3123924e491ed767','[\"*\"]','2026-06-17 07:01:41',NULL,'2026-06-17 06:25:44','2026-06-17 07:01:41'),(51,'App\\Models\\User',4,'WebDashboard','60d974f6ac2ca89f1776eaa29e220df9027b97d24a59cccbe27af3a110f03805','[\"*\"]','2026-06-17 07:31:40',NULL,'2026-06-17 06:48:13','2026-06-17 07:31:40'),(52,'App\\Models\\User',4,'WebDashboard','79688c4142764ec1c449d28e3f779bc01d4c7f6225989951acf6434acee74f5d','[\"*\"]','2026-06-17 07:49:57',NULL,'2026-06-17 07:03:53','2026-06-17 07:49:57'),(53,'App\\Models\\User',1,'WebDashboard','0827c06e198a9ba09e8c2e64e8e073bf6d7465cd99974ee0b6670f9346b155d9','[\"*\"]','2026-06-17 07:07:59',NULL,'2026-06-17 07:07:59','2026-06-17 07:07:59'),(54,'App\\Models\\User',3,'WebDashboard','8153776c7d9af848570a0c0b965b230cab93ec0cb2df227fed94501329449612','[\"*\"]','2026-06-17 07:47:04',NULL,'2026-06-17 07:11:03','2026-06-17 07:47:04'),(55,'App\\Models\\User',4,'WebDashboard','70d8f0372a903b9d9c93c14de12c3984b8ab96c3844f4d349006313397a63bcb','[\"*\"]','2026-06-17 07:35:29',NULL,'2026-06-17 07:31:59','2026-06-17 07:35:29'),(56,'App\\Models\\User',3,'WebDashboard','a9fb6104fccc722e2e21527dcdb9b7b0d9466f09a4ea9857f6b4c47df90c8bae','[\"*\"]','2026-06-17 08:06:58',NULL,'2026-06-17 07:47:29','2026-06-17 08:06:58'),(57,'App\\Models\\User',1,'WebDashboard','4cd8efb155c3bea901c4694eef17c631e355c550ad6a73eda0853f744b305cd3','[\"*\"]','2026-06-17 08:09:25',NULL,'2026-06-17 07:50:12','2026-06-17 08:09:25'),(58,'App\\Models\\User',4,'WebDashboard','461270c75606cee192686c1f88102c10f86d806d39ad424783fd615f6d9a989d','[\"*\"]','2026-06-17 08:09:32',NULL,'2026-06-17 08:07:30','2026-06-17 08:09:32'),(59,'App\\Models\\User',3,'WebDashboard','1bf4adff77287a4eecfdc23c1ab86f42d82c34217cefe78e428ffd9bcee54f96','[\"*\"]','2026-06-17 08:09:43',NULL,'2026-06-17 08:09:43','2026-06-17 08:09:43'),(60,'App\\Models\\User',4,'WebDashboard','ae702cc4d43909965ad3a200e823e5d8a0afa2e951c10dba657c454bb91b12fe','[\"*\"]','2026-06-18 10:29:11',NULL,'2026-06-17 08:10:09','2026-06-18 10:29:11'),(61,'App\\Models\\User',1,'WebDashboard','f450e99be1ba5e938e5013845fa72453c23dfe8ab972a94da4d968427a23ccd0','[\"*\"]','2026-06-18 11:39:42',NULL,'2026-06-17 08:15:15','2026-06-18 11:39:42'),(62,'App\\Models\\User',4,'WebDashboard','05443417fc5f076cf494386ae1962a04d550021696f25d97b6dee5bdca2002fb','[\"*\"]','2026-06-19 00:44:51',NULL,'2026-06-18 10:30:03','2026-06-19 00:44:51'),(63,'App\\Models\\User',3,'WebDashboard','28eb6658da794edd285267601cf658f9cc6a95c51042e17d8d1e0496a57743cc','[\"*\"]','2026-06-18 11:10:20',NULL,'2026-06-18 10:30:46','2026-06-18 11:10:20'),(64,'App\\Models\\User',4,'WebDashboard','de6689518cefc80b82ba26acf777556398d84d24621bfcb93c90de88177f9515','[\"*\"]','2026-06-19 05:47:02',NULL,'2026-06-19 05:47:02','2026-06-19 05:47:02'),(65,'App\\Models\\User',4,'WebDashboard','c80ba0cc3fe947007aea6b822ea6ac638557ae8db0864fd85bc2a419ab77ad82','[\"*\"]','2026-06-19 23:30:08',NULL,'2026-06-19 23:30:08','2026-06-19 23:30:08');
/*!40000 ALTER TABLE `personal_access_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sessions` (
  `id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint unsigned DEFAULT NULL,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` text COLLATE utf8mb4_unicode_ci,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_activity` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `sessions_user_id_index` (`user_id`),
  KEY `sessions_last_activity_index` (`last_activity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sessions`
--

LOCK TABLES `sessions` WRITE;
/*!40000 ALTER TABLE `sessions` DISABLE KEYS */;
INSERT INTO `sessions` VALUES ('Xb3DZliRmKJ693FvNgnc4sWtNoUCMT1qtoya5ktr',NULL,'127.0.0.1','Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36','eyJfdG9rZW4iOiJ5NjQ1T1MxSXVHVlk3djduWlBUeER5MTRwM0FyUWJwSE9WMU1GOHViIiwiX3ByZXZpb3VzIjp7InVybCI6Imh0dHA6XC9cLzEyNy4wLjAuMTo4MDAwIiwicm91dGUiOm51bGx9LCJfZmxhc2giOnsib2xkIjpbXSwibmV3IjpbXX19',1781603828);
/*!40000 ALTER TABLE `sessions` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `remember_token` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_email_unique` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'User 01','test@realptt.com',NULL,'$2y$12$agdxvUICx2jyZ89qdJovN.iSgJ.es06N84kYd4aSt.JSbe/s7/G1i',NULL,'2026-06-15 22:52:08','2026-06-15 22:52:08'),(3,'User 02','test2@realptt.com',NULL,'$2y$12$wTKESCiSUn.AovYJFobf2OMq4QAJFQ3cL4JXTmuoaf8YaMi2RBnRa',NULL,'2026-06-15 23:39:14','2026-06-15 23:39:14'),(4,'Admin','admin@realptt.com',NULL,'$2y$12$TAfHWcaCyi96aVAMkJmWt.ueD8SnNEDsvoOIlNsql3K3urS8O88D.',NULL,'2026-06-16 06:25:12','2026-06-16 06:25:12'),(6,'security_01','security_01@gmail.com',NULL,'$2y$12$vHe3Po6oP3BV.IQuGQfoB.47w5W0eiN/mY4ycspBui9j1kBZKspou',NULL,'2026-06-17 07:29:32','2026-06-17 07:29:32'),(7,'security_02','security_02@gmail.com',NULL,'$2y$12$BIZsMfypnP.6DrjbeZgZQOJUpRh236frte28lu5ibold8JX9xRj9O',NULL,'2026-06-17 07:29:33','2026-06-17 07:29:33');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-06-20 14:25:06

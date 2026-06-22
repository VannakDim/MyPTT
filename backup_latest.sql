-- MySQL dump 10.13  Distrib 8.0.46, for Linux (aarch64)
--
-- Host: localhost    Database: real_db
-- ------------------------------------------------------
-- Server version	8.0.46

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
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `group_user`
--

LOCK TABLES `group_user` WRITE;
/*!40000 ALTER TABLE `group_user` DISABLE KEYS */;
INSERT INTO `group_user` VALUES (1,2,1,NULL,NULL),(2,3,1,NULL,NULL),(3,4,1,NULL,NULL),(4,2,2,NULL,NULL),(5,4,2,NULL,NULL),(6,1,2,NULL,NULL),(7,1,1,NULL,NULL);
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
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `groups`
--

LOCK TABLES `groups` WRITE;
/*!40000 ALTER TABLE `groups` DISABLE KEYS */;
INSERT INTO `groups` VALUES (1,'security','ក្រុមសន្តិសុខទូទៅ','2026-06-20 08:21:59','2026-06-20 08:21:59'),(2,'control_room','បន្ទប់បញ្ជាការ','2026-06-20 08:21:59','2026-06-20 08:21:59');
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
  `migration` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `migrations`
--

LOCK TABLES `migrations` WRITE;
/*!40000 ALTER TABLE `migrations` DISABLE KEYS */;
INSERT INTO `migrations` VALUES (8,'0001_01_01_000000_create_users_table',1),(9,'0001_01_01_000001_create_cache_table',1),(10,'0001_01_01_000002_create_jobs_table',1),(11,'2026_06_16_045029_create_personal_access_tokens_table',1),(12,'2026_06_17_133633_create_groups_table',1),(13,'2026_06_17_133634_create_group_user_table',1),(14,'2026_06_20_151836_add_role_to_users_table',1),(15,'2026_06_20_090525_add_avatar_to_users_table',2);
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
) ENGINE=InnoDB AUTO_INCREMENT=29 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `personal_access_tokens`
--

LOCK TABLES `personal_access_tokens` WRITE;
/*!40000 ALTER TABLE `personal_access_tokens` DISABLE KEYS */;
INSERT INTO `personal_access_tokens` VALUES (1,'App\\Models\\User',1,'WebDashboard','92ed0eb03fe5f84b4c9238dca7d71aa939ce8a4c987eee95d9c3f08324fdef02','[\"*\"]','2026-06-20 15:37:57',NULL,'2026-06-20 08:26:54','2026-06-20 15:37:57'),(2,'App\\Models\\User',3,'WebDashboard','065df948ba90b4d4892f0fe87a95dd81271507224c256b9d94d0aeb5a48c2a9e','[\"*\"]','2026-06-20 09:00:38',NULL,'2026-06-20 08:28:35','2026-06-20 09:00:38'),(3,'App\\Models\\User',4,'WebDashboard','9fbf19c67bb9c32b78ddf1fa68b00280f4ea4d312084e4c3555d4ef852ae22c4','[\"*\"]','2026-06-21 12:42:36',NULL,'2026-06-20 08:47:13','2026-06-21 12:42:36'),(4,'App\\Models\\User',1,'WebDashboard','827ec155eaeaecbfee3ae7930c77b357ce00c16abb5ce6134b8f520d8b4f9299','[\"*\"]','2026-06-20 09:00:12',NULL,'2026-06-20 08:57:02','2026-06-20 09:00:12'),(5,'App\\Models\\User',4,'WebDashboard','c1426a0416ff3e19926b7c0a0b056b43c1ef336851b8863cf9fb0d6da2074f6d','[\"*\"]','2026-06-20 19:04:24',NULL,'2026-06-20 09:04:14','2026-06-20 19:04:24'),(6,'App\\Models\\User',1,'WebDashboard','9167aa4f2bed5e17752fe59ca0566b6a4a93b16ea2ccae5df1867b9c493a1c1e','[\"*\"]','2026-06-20 09:13:04',NULL,'2026-06-20 09:08:32','2026-06-20 09:13:04'),(7,'App\\Models\\User',1,'WebDashboard','b3382fa549e2bd1d68ab4e5404f1d30d1bd45031b0817dbc139f6d87b3c6659a','[\"*\"]','2026-06-20 09:39:28',NULL,'2026-06-20 09:22:35','2026-06-20 09:39:28'),(8,'App\\Models\\User',1,'WebDashboard','a3d1bf146fe07b8301873a3bc75e8d7ad2682d696da5fae67ae32ce16ce44c5f','[\"*\"]','2026-06-20 09:42:41',NULL,'2026-06-20 09:40:10','2026-06-20 09:42:41'),(9,'App\\Models\\User',1,'WebDashboard','4595c486077f0f7f88b25b9394ce29aa9a589c86b8e60055fd65c64e791c55b8','[\"*\"]','2026-06-20 15:14:50',NULL,'2026-06-20 09:43:33','2026-06-20 15:14:50'),(10,'App\\Models\\User',4,'WebDashboard','c1de4bfd660a3f7e77155d6e12636d48c7507e64650eaaf71456869607c1e853','[\"*\"]','2026-06-20 15:38:53',NULL,'2026-06-20 09:46:22','2026-06-20 15:38:53'),(11,'App\\Models\\User',4,'WebDashboard','8539f3ed78573c8e8a9ff50213791c2f90852ed04311bac0eea994961664884b','[\"*\"]','2026-06-20 15:40:11',NULL,'2026-06-20 15:40:11','2026-06-20 15:40:11'),(12,'App\\Models\\User',3,'WebDashboard','7f900fe08e6a977c8b7ddf5a5fecaec6e8854b9fd9c9b3291207ea9174a7fa66','[\"*\"]','2026-06-20 17:46:25',NULL,'2026-06-20 15:40:53','2026-06-20 17:46:25'),(13,'App\\Models\\User',1,'WebDashboard','3a7bafe0a04c9e03eb87d8cfc271968d7e980b638a5069f5df34db08e091460f','[\"*\"]','2026-06-20 16:16:31',NULL,'2026-06-20 15:49:00','2026-06-20 16:16:31'),(14,'App\\Models\\User',1,'MobileApp','8dad6f672e361c39e58faea7eac0b6dcc1c0b0a0e658be1e97eed5afb362f460','[\"*\"]','2026-06-20 16:13:19',NULL,'2026-06-20 16:12:45','2026-06-20 16:13:19'),(15,'App\\Models\\User',3,'MobileApp','c0e9bdbbea2e9b004969504d844c39b80373d5b687a5f8a39b82df5a58a914cc','[\"*\"]','2026-06-20 16:14:34',NULL,'2026-06-20 16:14:06','2026-06-20 16:14:34'),(16,'App\\Models\\User',1,'MobileApp','cae14965b74aae060f3ba1a4dea40fc3731a6ba56e0b28018e0f5e49f85a7315','[\"*\"]','2026-06-20 16:15:03',NULL,'2026-06-20 16:15:03','2026-06-20 16:15:03'),(17,'App\\Models\\User',1,'MobileApp','5393ddc96db8af5b8161dff7147df7b51c3d2bea1bac1d22fe9e98d797f71155','[\"*\"]','2026-06-20 16:20:52',NULL,'2026-06-20 16:20:52','2026-06-20 16:20:52'),(18,'App\\Models\\User',2,'MobileApp','d0df053051d0b7a654d7b3793855a784def39eac7e318e08426c60ffff1d397b','[\"*\"]','2026-06-20 16:35:11',NULL,'2026-06-20 16:35:10','2026-06-20 16:35:11'),(19,'App\\Models\\User',1,'MobileApp','b5596245e59e70a7e0d4d460aeeac893cd366f512a887a68ff9a67d2c41ade10','[\"*\"]','2026-06-20 17:58:27',NULL,'2026-06-20 17:37:46','2026-06-20 17:58:27'),(20,'App\\Models\\User',3,'WebDashboard','9bd5ca759eb88c32ead202a692a5a9d72302d520df3d79f668b6887d07ab5b88','[\"*\"]','2026-06-20 17:46:42',NULL,'2026-06-20 17:46:42','2026-06-20 17:46:42'),(21,'App\\Models\\User',1,'MobileApp','f185aaeceb29b0dbd0b33dac89207fe375357832aafe5262b2ab59f865f0817e','[\"*\"]','2026-06-20 18:01:01',NULL,'2026-06-20 17:55:57','2026-06-20 18:01:01'),(22,'App\\Models\\User',3,'MobileApp','d15c656b4ccb46a5aba6f03f0889b89ef203ca5ea21920d6541e5e52d76ca3a5','[\"*\"]','2026-06-20 18:04:17',NULL,'2026-06-20 18:02:46','2026-06-20 18:04:17'),(23,'App\\Models\\User',4,'MobileApp','4103a82e80fc07d4cd637a75e33eb7459bc4c733cc90af33c98b7904f45f553d','[\"*\"]','2026-06-20 18:03:50',NULL,'2026-06-20 18:03:36','2026-06-20 18:03:50'),(24,'App\\Models\\User',3,'MobileApp','c195c9617f3ca8f64fd69f6fe9cf47455f71ab92e323a80cb700937e3048ec49','[\"*\"]','2026-06-20 19:44:11',NULL,'2026-06-20 18:05:28','2026-06-20 19:44:11'),(25,'App\\Models\\User',2,'MobileApp','91550a5a72348f1d392ab7325082e52d8af3ad65faae1033898f3e8b0751248c','[\"*\"]','2026-06-20 18:06:10',NULL,'2026-06-20 18:06:10','2026-06-20 18:06:10'),(26,'App\\Models\\User',1,'WebDashboard','a45a512563df900bc8bd6655613f1f5c67ffdc534bf54462863e80ae6c67fa64','[\"*\"]','2026-06-22 08:25:48',NULL,'2026-06-20 18:08:32','2026-06-22 08:25:48'),(27,'App\\Models\\User',3,'MobileApp','b8985a695aa0cfee46294bec8cb09a4fa8f0a2e03cd3c1824902a49cdeeed088','[\"*\"]','2026-06-21 05:46:11',NULL,'2026-06-21 05:46:11','2026-06-21 05:46:11'),(28,'App\\Models\\User',3,'MobileApp','bb284f5b97b14f75d74ed188d615caa057b1235de9a8617bdcc9d10802461f9f','[\"*\"]','2026-06-21 11:16:44',NULL,'2026-06-21 11:00:59','2026-06-21 11:16:44');
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
INSERT INTO `sessions` VALUES ('7bzdqXhTLBqkvKsCRpyQl3qff7eQbEaCS7lFNZmv',NULL,'192.168.65.1','Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36','eyJfdG9rZW4iOiI3OGlWcmNMUGdLQzdQNjdHMjhhQ3dBS2VWUUhuVVY1QmpuWXpQc2I4IiwiX3ByZXZpb3VzIjp7InVybCI6Imh0dHA6XC9cL2xvY2FsaG9zdDo4MDAwIiwicm91dGUiOm51bGx9LCJfZmxhc2giOnsib2xkIjpbXSwibmV3IjpbXX19',1781943890);
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
  `role` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'user',
  `avatar` longtext COLLATE utf8mb4_unicode_ci,
  `remember_token` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_email_unique` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'Admin User','admin@realptt.com',NULL,'$2y$12$8hzLXcFLcwOnKYOUmALc.O5/69WxgwPJEdzD9dArVKfFg7a3xlsqi','admin',NULL,NULL,'2026-06-20 08:21:57','2026-06-20 09:47:53'),(2,'admin','admin@gmail.com',NULL,'$2y$12$ythGi3PoK5LMjIszY67tjumQHZCVAPYHHvVuC8/AZ/uYnoCJy7y.e','admin',NULL,NULL,'2026-06-20 08:22:00','2026-06-20 08:22:00'),(3,'security_01','security_01@gmail.com',NULL,'$2y$12$hb9MREZf2A035wyWRM1R0eVk50FEtUZpo9IVjR4IG2ZxS8BKoGw82','user',NULL,NULL,'2026-06-20 08:22:00','2026-06-20 08:22:00'),(4,'security_02','security_02@gmail.com',NULL,'$2y$12$b0C91QAXsAVZyV1JvvNeVO056abnoqEEESLg7NpPS8W1Vq4fhsF6y','user',NULL,NULL,'2026-06-20 08:22:00','2026-06-20 09:45:29');
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

-- Dump completed on 2026-06-22  8:31:41

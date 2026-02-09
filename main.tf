module "storage" {
  source = "./modules/storage"
}

module "compute" {
  source              = "./modules/compute"
  raw_bucket_id       = module.storage.raw_bucket_id
  raw_bucket_arn      = module.storage.raw_bucket_arn
  processed_bucket_id = module.storage.processed_bucket_id
  processed_bucket_arn = module.storage.processed_bucket_arn
  notification_email  = "22ht1a05f0@city.ac.in" # <--- REPLACE THIS
}

-- 1. Tipe Data Enum untuk Role dan Status
CREATE TYPE user_role AS ENUM ('Petugas_Lapangan', 'Kordinator_Divisi', 'Admin');
CREATE TYPE status_observasi AS ENUM ('MENUNGGU_VERIFIKASI', 'TERVERIFIKASI', 'PERLU_DIREVISI');

-- 2. Tabel Profil Pengguna 
CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  nama_lengkap TEXT NOT NULL,
  role user_role DEFAULT 'Petugas_Lapangan',
  divisi_takson TEXT, -- Contoh: 'Mamalia', 'Flora' (Khusus Kordinator)
  status_aktivitas BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Tabel Kegiatan (Program rutin/Ekspedisi)
CREATE TABLE kegiatan (
  id SERIAL PRIMARY KEY,
  nama_kegiatan TEXT NOT NULL,
  deskripsi TEXT,
  tanggal_mulai DATE,
  tanggal_selesai DATE
);

-- 4. Tabel Utama: Data Observasi
CREATE TABLE data_observasi (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  id_petugas UUID REFERENCES profiles(id) NOT NULL,
  id_kegiatan INTEGER REFERENCES kegiatan(id),
  
  -- Data Biologis
  nama_spesies TEXT NOT NULL,
  kategori_takson TEXT NOT NULL, 
  
  -- Data Spasial & Media
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  foto_url TEXT NOT NULL,
  
  -- Data Tambahan
  catatan_habitat TEXT,
  waktu_pengamatan TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Status Approval
  status_approval status_observasi DEFAULT 'MENUNGGU_VERIFIKASI'
);

-- 5. Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE kegiatan ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_observasi ENABLE ROW LEVEL SECURITY;

-- 6. Policy
CREATE POLICY "Bisa lihat semua observasi" ON data_observasi FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Petugas bisa tambah observasi" ON data_observasi FOR INSERT WITH CHECK (auth.role() = 'authenticated');
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/storage/storage_manager.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Kebijakan Privasi',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: PrivacyPolicyContent(),
      ),
    );
  }

  /// Menampilkan Bottom Sheet Persetujuan (Mandatory)
  static Future<void> showAcceptanceSheet(BuildContext context) async {
    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _PrivacyAcceptanceSheet(),
    );
  }
}

class PrivacyPolicyContent extends StatelessWidget {
  const PrivacyPolicyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 32),
        _buildSection(
          title: '1. Pendahuluan',
          content:
              'Selamat datang di Conversa, aplikasi manajemen tiket internal FIFGROUP. Kami sangat menghargai privasi Anda dan berkomitmen untuk melindungi data pribadi Anda. Kebijakan ini menjelaskan bagaimana kami mengumpulkan, menggunakan, dan menjaga keamanan informasi Anda saat menggunakan aplikasi ini.',
        ),
        _buildSection(
          title: '2. Informasi yang Kami Kumpulkan',
          content: 'Kami mengumpulkan informasi yang diperlukan untuk operasional sistem ticketing, antara lain:',
          bullets: [
            'Informasi Profil: Nama lengkap, nomor karyawan (NIK), jabatan, level, dan lokasi kerja.',
            'Informasi Akun: Email perusahaan dan kredensial akses yang aman.',
            'Data Tiket & Chat: Seluruh isi pesan, lampiran (gambar/dokumen), dan riwayat interaksi dalam forum atau tiket bantuan.',
            'Informasi Perangkat: Token Firebase Cloud Messaging (FCM) untuk pengiriman notifikasi realtime, model perangkat, dan versi sistem operasi.',
          ],
        ),
        _buildSection(
          title: '3. Penggunaan Informasi',
          content: 'Informasi yang kami kumpulkan digunakan untuk:',
          bullets: [
            'Memastikan identitas pengguna adalah karyawan FIFGROUP yang sah.',
            'Memproses, menugaskan, dan menyelesaikan tiket bantuan secara efisien.',
            'Mengirimkan notifikasi penting mengenai status tiket atau update informasi terbaru.',
            'Melakukan audit internal dan peningkatan kualitas layanan teknologi informasi.',
          ],
        ),
        _buildSection(
          title: '4. Keamanan Data',
          content:
              'Kami menerapkan standar keamanan teknis yang ketat untuk melindungi data Anda dari akses yang tidak sah, kebocoran, atau perubahan data. Seluruh komunikasi data antara aplikasi dan server telah dienkripsi menggunakan protokol keamanan standar industri.',
        ),
        _buildSection(
          title: '5. Hak Pengguna',
          content: 'Sebagai pengguna, Anda berhak untuk:',
          bullets: [
            'Melihat dan memastikan data profil Anda akurat.',
            'Memperbarui kata sandi secara berkala melalui menu keamanan.',
            'Melaporkan penyalahgunaan data atau kendala privasi kepada tim IT Security.',
          ],
        ),
        _buildSection(
          title: '6. Perubahan Kebijakan',
          content:
              'Kebijakan ini dapat berubah sewaktu-waktu mengikuti perkembangan regulasi perusahaan atau fitur aplikasi. Perubahan signifikan akan diinformasikan kepada Anda melalui notifikasi di dalam aplikasi.',
        ),
        const SizedBox(height: 24),
        _buildFooter(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 40),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Terakhir diperbarui: 25 April 2026',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textDark.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required String content, List<String>? bullets}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textDark.withValues(alpha: 0.8),
              height: 1.6,
            ),
          ),
          if (bullets != null) ...[
            const SizedBox(height: 12),
            ...bullets.map((bullet) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          bullet,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textDark.withValues(alpha: 0.8),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 24),
          Text(
            'Conversa by FIFGROUP',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2026 PT Federal International Finance',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textDark.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyAcceptanceSheet extends StatelessWidget {
  const _PrivacyAcceptanceSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Persetujuan Kebijakan Privasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: const PrivacyPolicyContent(),
            ),
          ),
          // Action Button
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Dengan menekan "Saya Setuju", Anda menyatakan telah membaca dan menyetujui seluruh ketentuan kebijakan privasi di atas.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () async {
                        await StorageManager.setPrivacyPolicyAccepted();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Saya Setuju',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

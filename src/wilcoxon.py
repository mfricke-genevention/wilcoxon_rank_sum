import pandas as pd
import argparse
import sys
import os

from scipy.stats import mannwhitneyu
from statsmodels.stats.multitest import multipletests
from sklearn.decomposition import PCA
import matplotlib.pyplot as plt

output_folder = "./wilcoxon_result"

def pca(full_df, columns, condition, conditions):
    data = full_df[columns]
    # Normalize the continuous variables for PCA
    data_normalized = (data - data.mean()) / data.std()

    # Perform PCA
    pca = PCA(n_components=2)
    pca_result = pca.fit_transform(data_normalized)

    # Add PCA results to the dataframe
    full_df['PCA1'] = pca_result[:, 0]
    full_df['PCA2'] = pca_result[:, 1]

    full_df[["sample", "PCA1", "PCA2"]].to_csv(f"{output_folder}/pca.csv", index=False)

    # Plot the PCA result
    plt.figure(figsize=(8, 6))
    # print(conditions)
    plt.scatter(full_df[full_df[condition] == conditions[0]]['PCA1'],
                full_df[full_df[condition] == conditions[0]]['PCA2'], label=conditions[0])
    plt.scatter(full_df[full_df[condition] == conditions[1]]['PCA1'],
                full_df[full_df[condition] == conditions[1]]['PCA2'], label=conditions[1])
    plt.title('PCA')
    plt.xlabel('PCA1')
    plt.ylabel('PCA2')
    plt.legend(conditions)
    # specify filename, format, and dpi
    plt.savefig(f"{output_folder}/pca.png", format="png", dpi=300)


def wilcoxon(metadata_path, data_path, condition):
    metadata_df = pd.read_csv(metadata_path)
    data_df = pd.read_csv(data_path)

    os.makedirs(output_folder, exist_ok=True)

    data_df_t = data_df.T
    columns = data_df_t.iloc[0]
    data_df_t.columns = columns
    data_df_t = data_df_t.iloc[1:]
    data_df_t["ID"] = data_df_t.index
    full_df = metadata_df.merge(data_df_t, left_on=["sample"], right_on="ID")

    entity_names = data_df.ID
    grouped = full_df.groupby(condition)
    dfs_by_group = {name: group for name, group in grouped}
    conditions = list(dfs_by_group.keys())
    if len(conditions) != 2:
        raise ValueError(
            f"To perform a Wilcoxon test, we need exactly 2 conditions. Input conditions found: {conditions}")
    else:
        pca(full_df, columns, condition, conditions)
        wilcoxon_results = []
        # 2. Perform Wilcoxon rank-sum test for each gene
        for entity in entity_names:
            condition_1 = dfs_by_group[conditions[0]]
            condition_2 = dfs_by_group[conditions[1]]
            set_1 = condition_1[entity].astype(float)
            set_2 = condition_2[entity].astype(float)
            # Perform the Wilcoxon test between groups
            stat, p_value = mannwhitneyu(set_1, set_2, alternative='two-sided')

            # Store the gene, test statistic, and p-value
            wilcoxon_results.append(
                {'Entity': entity, 'Statistic': stat, 'P_Value': p_value})

        # Convert the results into a DataFrame
        wilcoxon_df = pd.DataFrame(wilcoxon_results)

        # 3. Adjust p-values using the Benjamini-Hochberg method
        _, pvals_adj, _, _ = multipletests(
            wilcoxon_df['P_Value'], method='fdr_bh')

        # Add adjusted p-values to the results DataFrame
        wilcoxon_df['Adjusted_P_Value'] = pvals_adj
        wilcoxon_df.to_csv(f"{output_folder}/result.csv")


def option_parser():
    parser = argparse.ArgumentParser(description="metadata2table")
    parser.add_argument('--metadata', "-m",
                        help='metadata json file', dest="metadata")
    parser.add_argument('--data', "-d",
                        help='data count file', dest="data")
    parser.add_argument('--condition', "-c",
                        help='condition column', dest="condition")
    args = parser.parse_args()

    if len(sys.argv) < 3:
        parser.print_help()
        sys.exit("Missing parameters!")

    return args


def main():
    args = option_parser()
    data_path = args.data
    metadata_path = args.metadata
    condition = args.condition
    wilcoxon(metadata_path, data_path, condition)


if __name__ == "__main__":
    main()
